// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./SimpleAggregator.sol";
import "../Interfaces/EthBondMakerInterface.sol";
import "./ReserveETH.sol";
import "../utils/TransferETH.sol";

contract SimpleAggregatorCollateralizedEth is SimpleAggregator, TransferETH {
    using SafeMath for uint256;
    ReserveEth reserveEth;

    constructor(
        BondMakerInterface _bondMaker,
        LatestPriceOracleInterface _oracle,
        BondPricerInterface _pricer,
        SimpleStrategyInterface strategy,
        address exchangeAddress,
        int16 _maxSupplyDenumerator,
        VolatilityOracleInterface _volOracle,
        uint32 _priceUnit
    )
        SimpleAggregator(
            _bondMaker,
            _oracle,
            _pricer,
            strategy,
            exchangeAddress,
            _maxSupplyDenumerator,
            _priceUnit,
            _volOracle
        )
    {
        _setPool(_bondMaker, _volOracle, _pricer, _oracle);
        reserveEth = new ReserveEth();
    }

    function _setPool(
        BondMakerInterface bondMaker,
        VolatilityOracleInterface _volOracle,
        BondPricerInterface _pricer,
        LatestPriceOracleInterface _oracle
    ) internal {
        int16 feeBaseE4 = STRATEGY.getCurrentSpread();
        currentFeeBase = feeBaseE4;
        DOTC.createVsBondPool(
            bondMaker,
            _volOracle,
            _pricer,
            _pricer,
            feeBaseE4
        );
        DOTC.createVsEthPool(_oracle, _pricer, feeBaseE4, true);
        DOTC.createVsEthPool(_oracle, _pricer, feeBaseE4, false);
    }

    function changeSpread() public {
        currentFeeBase = STRATEGY.getCurrentSpread();

        require(
            currentFeeBase <= 1000 && currentFeeBase >= 5,
            "Invalid  feebase"
        );
        bytes32 poolIDETHSell = DOTC.generateVsEthPoolID(address(this), true);
        bytes32 poolIDETHBuy = DOTC.generateVsEthPoolID(address(this), false);

        bytes32 poolIDBond = DOTC.generateVsBondPoolID(
            address(this),
            address(bondMaker)
        );

        DOTC.updateVsEthPool(poolIDETHSell, oracle, bondPricer, currentFeeBase);

        DOTC.updateVsEthPool(poolIDETHBuy, oracle, bondPricer, currentFeeBase);

        DOTC.updateVsBondPool(
            poolIDBond,
            volOracle,
            bondPricer,
            bondPricer,
            currentFeeBase
        );
    }

    function addLiquidity()
        external
        payable
        isSafeSupply
        returns (bool success)
    {
        success = _addLiquidity(msg.value);
    }

    function _applyDecimalGap(uint256 amount, bool isDiv)
        internal
        view
        override
        returns (uint256)
    {
        if (isDiv) {
            return amount / 10**10;
        } else {
            return amount * 10**10;
        }
    }

    function _sendTokens(address user, uint256 amount) internal override {
        reserveEth.sendAsset(payable(user), amount);
    }

    function getCollateralAmount() external view override returns (uint256) {
        return address(this).balance;
    }

    function isEthAggregator() external pure override returns (bool) {
        return true;
    }

    function _reserveAsset(uint256 reserveAmountRatioE8) internal override {
        uint256 amount = address(this).balance.mul(reserveAmountRatioE8).div(
            10**decimals
        );
        _transferETH(payable(address(reserveEth)), amount);
    }

    function _issueBonds(uint256 bondgroupID, uint256 amount)
        internal
        override
    {
        EthBondMakerInterface bm = EthBondMakerInterface(address(bondMaker));
        bm.issueNewBonds{value: amount.mul(10**10)}(bondgroupID);
    }

    function _getCollateralAmount() internal view override returns (uint256) {
        return address(this).balance.sub(totalReceivedCollateral[currentTerm]);
    }

    function getCollateralDecimal() external view override returns (int16) {
        return 18;
    }

    function getReserveAddress() external view override returns (address) {
        return address(reserveEth);
    }
}
