// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "../BondToken_and_GDOTC/bondPricer/BondPricerInterface.sol";
import "../BondToken_and_GDOTC/bondPricer/CustomGeneralizedPricing.sol";
import "../../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../BondToken_and_GDOTC/util/Time.sol";

contract BondPricerWithAcceptableMaturity is CustomGeneralizedPricing, Ownable, Time {
    using SafeMath for uint256;

    uint256 internal _acceptableMaturity;

    event LogUpdateAcceptableMaturity(uint256 acceptableMaturity);

    constructor(address originalBondPricerAddress)
        CustomGeneralizedPricing(originalBondPricerAddress)
    {
        _updateAcceptableMaturity(0);
    }

    function updateAcceptableMaturity(uint256 acceptableMaturity) external onlyOwner {
        _updateAcceptableMaturity(acceptableMaturity);
    }

    function getAcceptableMaturity() external view returns (uint256 acceptableMaturity) {
        acceptableMaturity = _acceptableMaturity;
    }

    function _updateAcceptableMaturity(uint256 acceptableMaturity) internal {
        _acceptableMaturity = acceptableMaturity;
        emit LogUpdateAcceptableMaturity(acceptableMaturity);
    }

    function _isAcceptableLbt(
        uint256[] memory,
        int256 etherPriceE8,
        int256 ethVolatilityE8,
        int256 untilMaturity,
        uint256,
        uint256
    ) internal view override returns (bool) {
        _isAcceptable(etherPriceE8, ethVolatilityE8, untilMaturity);
        return true;
    }

    function _isAcceptableSbt(
        uint256[] memory,
        int256 etherPriceE8,
        int256 ethVolatilityE8,
        int256 untilMaturity,
        uint256,
        uint256
    ) internal view override returns (bool) {
        _isAcceptable(etherPriceE8, ethVolatilityE8, untilMaturity);
        return true;
    }

    function _isAcceptableTriangleBond(
        uint256[] memory,
        int256 etherPriceE8,
        int256 ethVolatilityE8,
        int256 untilMaturity,
        uint256,
        uint256
    ) internal view override returns (bool) {
        _isAcceptable(etherPriceE8, ethVolatilityE8, untilMaturity);
        return true;
    }

    function _isAcceptablePureSbt(
        uint256[] memory,
        int256 etherPriceE8,
        int256 ethVolatilityE8,
        int256 untilMaturity,
        uint256,
        uint256
    ) internal view override returns (bool) {
        _isAcceptable(etherPriceE8, ethVolatilityE8, untilMaturity);
        return true;
    }

    function _isAcceptableOtherBond(
        uint256[] memory,
        int256,
        int256,
        int256,
        uint256,
        uint256
    ) internal pure override returns (bool) {
        revert("the bond is not pure SBT type");
    }

    /**
     * @notice Add this function to CustomGeneralizedPricing
     * When user sells bond which expired or whose maturity is after the aggregator's maturity, revert the transaction
     */
    function _isAcceptable(
        int256 etherPriceE8,
        int256 ethVolatilityE8,
        int256 untilMaturity
    ) internal view {
        require(
            etherPriceE8 > 0 && etherPriceE8 < 100000 * 10**8,
            "ETH price should be between $0 and $100000"
        );
        require(
            ethVolatilityE8 > 0 && ethVolatilityE8 < 10 * 10**8,
            "ETH volatility should be between 0% and 1000%"
        );
        require(untilMaturity >= 0, "the bond has been expired");
        require(untilMaturity <= 12 weeks, "the bond maturity must be less than 12 weeks");
        require(
            _getBlockTimestampSec().add(uint256(untilMaturity)) <= _acceptableMaturity,
            "the bond maturity must not exceed the current maturity of aggregator"
        );
    }
}
