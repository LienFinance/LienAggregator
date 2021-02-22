// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "../../../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../math/UseSafeMath.sol";
import "../oracle/OracleInterface.sol";
import "../oracle/VolatilityOracleInterface.sol";
import "../bondMaker/BondMakerInterface.sol";
import "../bondPricer/BondPricerInterface.sol";
import "../bondPricer/DetectBondShape.sol";
import "../bondToken/BondTokenInterface.sol";
import "../util/Time.sol";

abstract contract BondExchange is Time {
    using SafeMath for uint256;
    using SafeCast for uint256;

    uint256 internal constant MIN_EXCHANGE_RATE_E8 = 0.000001 * 10**8;
    uint256 internal constant MAX_EXCHANGE_RATE_E8 = 1000000 * 10**8;

    int256 internal constant MAX_SPREAD_E8 = 10**8; // 100%

    /**
     * @dev the sum of decimalsOfBond of the bondMaker.
     * This value is constant by the restriction of `_assertBondMakerDecimals`.
     */
    uint8 internal constant DECIMALS_OF_BOND = 8;

    /**
     * @dev the sum of decimalsOfOraclePrice of the bondMaker.
     * This value is constant by the restriction of `_assertBondMakerDecimals`.
     */
    uint8 internal constant DECIMALS_OF_ORACLE_PRICE = 8;

    BondMakerInterface internal immutable _bondMakerContract;
    PriceOracleInterface internal immutable _priceOracleContract;
    VolatilityOracleInterface internal immutable _volatilityOracleContract;
    LatestPriceOracleInterface internal immutable _volumeCalculator;
    DetectBondShape internal immutable _bondShapeDetector;

    /**
     * @param bondMakerAddress is a bond maker contract.
     * @param volumeCalculatorAddress is a contract to convert the unit of a strike price to USD.
     */
    constructor(
        BondMakerInterface bondMakerAddress,
        VolatilityOracleInterface volatilityOracleAddress,
        LatestPriceOracleInterface volumeCalculatorAddress,
        DetectBondShape bondShapeDetector
    ) {
        _assertBondMakerDecimals(bondMakerAddress);
        _bondMakerContract = bondMakerAddress;
        _priceOracleContract = bondMakerAddress.oracleAddress();
        _volatilityOracleContract = VolatilityOracleInterface(volatilityOracleAddress);
        _volumeCalculator = volumeCalculatorAddress;
        _bondShapeDetector = bondShapeDetector;
    }

    function bondMakerAddress() external view returns (BondMakerInterface) {
        return _bondMakerContract;
    }

    function volumeCalculatorAddress() external view returns (LatestPriceOracleInterface) {
        return _volumeCalculator;
    }

    /**
     * @dev Get the latest price (USD) and historical volatility using oracle.
     * If the oracle is not working, `latestPrice` reverts.
     * @return priceE8 (10^-8 USD)
     */
    function _getLatestPrice(LatestPriceOracleInterface oracle) internal returns (uint256 priceE8) {
        return oracle.latestPrice();
    }

    /**
     * @dev Get the implied volatility using oracle.
     * @return volatilityE8 (10^-8)
     */
    function _getVolatility(VolatilityOracleInterface oracle, uint64 untilMaturity)
        internal
        view
        returns (uint256 volatilityE8)
    {
        return oracle.getVolatility(untilMaturity);
    }

    /**
     * @dev Returns bond tokenaddress, maturity,
     */
    function _getBond(BondMakerInterface bondMaker, bytes32 bondID)
        internal
        view
        returns (
            ERC20 bondToken,
            uint256 maturity,
            uint256 sbtStrikePrice,
            bytes32 fnMapID
        )
    {
        address bondTokenAddress;
        (bondTokenAddress, maturity, sbtStrikePrice, fnMapID) = bondMaker.getBond(bondID);

        // Revert if `bondTokenAddress` is zero.
        bondToken = ERC20(bondTokenAddress);
    }

    /**
     * @dev Removes a decimal gap from the first argument.
     */
    function _applyDecimalGap(
        uint256 baseAmount,
        uint8 decimalsOfBase,
        uint8 decimalsOfQuote
    ) internal pure returns (uint256 quoteAmount) {
        uint256 n;
        uint256 d;

        if (decimalsOfBase > decimalsOfQuote) {
            d = decimalsOfBase - decimalsOfQuote;
        } else if (decimalsOfBase < decimalsOfQuote) {
            n = decimalsOfQuote - decimalsOfBase;
        }

        // The consequent multiplication would overflow under extreme and non-blocking circumstances.
        require(n < 19 && d < 19, "decimal gap needs to be lower than 19");
        return baseAmount.mul(10**n).div(10**d);
    }

    function _calcBondPriceAndSpread(
        BondPricerInterface bondPricer,
        bytes32 bondID,
        int16 feeBaseE4
    ) internal returns (uint256 bondPriceE8, int256 spreadE8) {
        (, uint256 maturity, , ) = _getBond(_bondMakerContract, bondID);
        (bool isKnownBondType, BondType bondType, uint256[] memory points) = _bondShapeDetector
            .getBondTypeByID(_bondMakerContract, bondID, BondType.NONE);
        require(isKnownBondType, "cannot calculate the price of this bond");

        uint256 untilMaturity = maturity.sub(
            _getBlockTimestampSec(),
            "the bond should not have expired"
        );
        uint256 oraclePriceE8 = _getLatestPrice(_priceOracleContract);
        uint256 oracleVolatilityE8 = _getVolatility(
            _volatilityOracleContract,
            untilMaturity.toUint64()
        );

        uint256 leverageE8;
        (bondPriceE8, leverageE8) = bondPricer.calcPriceAndLeverage(
            bondType,
            points,
            oraclePriceE8.toInt256(),
            oracleVolatilityE8.toInt256(),
            untilMaturity.toInt256()
        );
        spreadE8 = _calcSpread(oracleVolatilityE8, leverageE8, feeBaseE4);
    }

    function _calcSpread(
        uint256 oracleVolatilityE8,
        uint256 leverageE8,
        int16 feeBaseE4
    ) internal pure returns (int256 spreadE8) {
        uint256 volE8 = oracleVolatilityE8 < 10**8 ? 10**8 : oracleVolatilityE8 > 2 * 10**8
            ? 2 * 10**8
            : oracleVolatilityE8;
        uint256 volTimesLevE16 = volE8 * leverageE8;
        // assert(volTimesLevE16 < 200 * 10**16);
        spreadE8 =
            (feeBaseE4 *
                (feeBaseE4 < 0 || volTimesLevE16 < 10**16 ? 10**16 : volTimesLevE16).toInt256()) /
            10**12;
        spreadE8 = spreadE8 > MAX_SPREAD_E8 ? MAX_SPREAD_E8 : spreadE8;
    }

    /**
     * @dev Calculate the exchange volume on the USD basis.
     */
    function _calcUsdPrice(uint256 amount) internal returns (uint256) {
        return amount.mul(_getLatestPrice(_volumeCalculator)) / 10**8;
    }

    /**
     * @dev Restirct the bond maker.
     */
    function _assertBondMakerDecimals(BondMakerInterface bondMaker) internal view {
        require(
            bondMaker.decimalsOfOraclePrice() == DECIMALS_OF_ORACLE_PRICE,
            "the decimals of oracle price must be 8"
        );
        require(
            bondMaker.decimalsOfBond() == DECIMALS_OF_BOND,
            "the decimals of bond token must be 8"
        );
    }

    function _assertExpectedPriceRange(
        uint256 actualAmount,
        uint256 expectedAmount,
        uint256 range
    ) internal pure {
        if (expectedAmount != 0) {
            require(
                actualAmount.mul(1000 + range).div(1000) >= expectedAmount,
                "out of expected price range"
            );
        }
    }
}
