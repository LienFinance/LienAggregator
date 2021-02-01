// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

import "./SimpleAggregator.sol";
import "../BondToken_and_GDOTC/bondMaker/BondMakerCollateralizedEthInterface.sol";
import "./ReserveETH.sol";
import "../BondToken_and_GDOTC/util/TransferETH.sol";

contract SimpleAggregatorCollateralizedEth is SimpleAggregator, TransferETH {
    using SafeMath for uint256;
    ReserveEth immutable reserveEth;
    uint16 public constant DECIMAL_GAP = 10;

    constructor(
        LatestPriceOracleInterface _ethOracle,
        BondPricerWithAcceptableMaturity _pricer,
        SimpleStrategyInterface strategy,
        ERC20 _rewardToken,
        BondRegistratorInterface _registrator,
        ExchangeInterface exchangeAddress,
        VolatilityOracleInterface _volOracle,
        uint64 _priceUnit,
        uint64 _firstRewardRate
    )
        SimpleAggregator(
            _ethOracle,
            _pricer,
            strategy,
            _rewardToken,
            _registrator,
            exchangeAddress,
            _priceUnit,
            _firstRewardRate,
            false,
            _volOracle
        )
    {
        BondMakerInterface _bondMaker = exchangeAddress.bondMakerAddress();
        _setPool(_bondMaker, _volOracle, _pricer, _ethOracle);
        reserveEth = new ReserveEth();
    }

    function _setPool(
        BondMakerInterface _bondMaker,
        VolatilityOracleInterface _volOracle,
        BondPricerInterface _pricer,
        LatestPriceOracleInterface _ethOracle
    ) internal {
        int16 feeBaseE4 =
            STRATEGY.getCurrentSpread(msg.sender, address(_ethOracle), false);
        currentFeeBase = feeBaseE4;
        DOTC.createVsBondPool(
            _bondMaker,
            _volOracle,
            _pricer,
            _pricer,
            feeBaseE4
        );
        DOTC.createVsEthPool(_ethOracle, _pricer, feeBaseE4, true);
        DOTC.createVsEthPool(_ethOracle, _pricer, feeBaseE4, false);
    }

    function changeSpread() public override {
        currentFeeBase = STRATEGY.getCurrentSpread(
            OWNER,
            address(ORACLE),
            false
        );

        require(
            currentFeeBase <= 1000 && currentFeeBase >= 5,
            "Invalid feebase"
        );
        bytes32 poolIDETHSell = DOTC.generateVsEthPoolID(address(this), true);
        bytes32 poolIDETHBuy = DOTC.generateVsEthPoolID(address(this), false);

        bytes32 poolIDBond =
            DOTC.generateVsBondPoolID(address(this), address(BONDMAKER));

        DOTC.updateVsEthPool(
            poolIDETHSell,
            ORACLE,
            BOND_PRICER,
            currentFeeBase
        );

        DOTC.updateVsEthPool(poolIDETHBuy, ORACLE, BOND_PRICER, currentFeeBase);

        DOTC.updateVsBondPool(
            poolIDBond,
            volOracle,
            BOND_PRICER,
            BOND_PRICER,
            currentFeeBase
        );
    }

    /**
     * @notice Receive ETH, then call _addLiquidity
     */
    function addLiquidity()
        external
        payable
        isSafeSupply
        returns (bool success)
    {
        success = _addLiquidity(msg.value);
    }

    function _sendTokens(address user, uint256 amount) internal override {
        reserveEth.sendAsset(payable(user), amount);
    }

    function _reserveAsset(uint256 collateralPerTokenE8) internal override {
        uint256 amount =
            _applyDecimalGap(
                uint256(totalUnremovedTokens[currentTerm])
                    .mul(collateralPerTokenE8)
                    .div(10**decimals),
                false
            );
        _transferETH(payable(address(reserveEth)), amount);
    }

    function _issueBonds(uint256 bondgroupID, uint256 amount)
        internal
        override
    {
        BondMakerCollateralizedEthInterface bm =
            BondMakerCollateralizedEthInterface(address(BONDMAKER));
        bm.issueNewBonds{value: amount.mul(10**10).mul(1002).div(1000)}(
            bondgroupID
        );
    }

    function getCollateralAddress() external pure override returns (address) {
        return address(0);
    }

    /**
     * @dev Decimal gap between ETH and share token is 10
     */
    function _applyDecimalGap(uint256 amount, bool isDiv)
        internal
        pure
        override
        returns (uint256)
    {
        if (isDiv) {
            return amount / 10**DECIMAL_GAP;
        } else {
            return amount * 10**DECIMAL_GAP;
        }
    }

    /**
     * @notice Get available collateral amount in this term
     */
    function getCollateralAmount() public view override returns (uint256) {
        return address(this).balance.sub(totalReceivedCollateral[currentTerm]);
    }

    function getCollateralDecimal() external pure override returns (int16) {
        return 18;
    }

    function getReserveAddress() external view override returns (address) {
        return address(reserveEth);
    }
}
