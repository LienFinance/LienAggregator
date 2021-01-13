// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./SimpleAggregator.sol";
import "../Interfaces/ERC20BondMakerInterface.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./ReserveERC20.sol";

contract SimpleAggregatorCollateralizedERC20 is SimpleAggregator {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;
    ERC20 collateralToken;
    int16 decimalGap;
    ReserveERC20 reserveERC20;

    constructor(
        BondMakerInterface _bondMaker,
        LatestPriceOracleInterface _oracle,
        BondPricerInterface _pricer,
        SimpleStrategyInterface strategy,
        address exchangeAddress,
        int16 _maxSupplyDenumerator,
        address _collateralAddress,
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
        collateralToken = ERC20(_collateralAddress);
        collateralToken.approve(address(_bondMaker), uint256(-1));
        _setPool(_bondMaker, _volOracle, _pricer, _oracle, _collateralAddress);
        decimalGap = int16(collateralToken.decimals()) - decimals;
        reserveERC20 = new ReserveERC20(collateralToken);
    }

    function _setPool(
        BondMakerInterface bondMaker,
        VolatilityOracleInterface _volOracle,
        BondPricerInterface _pricer,
        LatestPriceOracleInterface _oracle,
        address _collateralAddress
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

        DOTC.createVsErc20Pool(
            ERC20(_collateralAddress),
            _oracle,
            _pricer,
            feeBaseE4,
            true
        );

        DOTC.createVsErc20Pool(
            ERC20(_collateralAddress),
            _oracle,
            _pricer,
            feeBaseE4,
            false
        );
    }

    function changeSpread() public {
        currentFeeBase = STRATEGY.getCurrentSpread();

        require(
            currentFeeBase <= 1000 && currentFeeBase >= 5,
            "Invalid  feebase"
        );
        bytes32 poolIDTokenSell = DOTC.generateVsErc20PoolID(
            address(this),
            address(collateralToken),
            true
        );
        bytes32 poolIDTokenBuy = DOTC.generateVsErc20PoolID(
            address(this),
            address(collateralToken),
            false
        );

        bytes32 poolIDBond = DOTC.generateVsBondPoolID(
            address(this),
            address(bondMaker)
        );

        DOTC.updateVsErc20Pool(
            poolIDTokenSell,
            oracle,
            bondPricer,
            currentFeeBase
        );

        DOTC.updateVsErc20Pool(
            poolIDTokenBuy,
            oracle,
            bondPricer,
            currentFeeBase
        );

        DOTC.updateVsBondPool(
            poolIDBond,
            volOracle,
            bondPricer,
            bondPricer,
            currentFeeBase
        );
    }

    function _applyDecimalGap(uint256 amount, bool isDiv)
        internal
        view
        override
        returns (uint256)
    {
        if (isDiv) {
            if (decimalGap > 0) {
                return amount.div(10**uint256(decimalGap));
            } else {
                return amount.mul(10**uint256(decimalGap * -1));
            }
        } else {
            if (decimalGap > 0) {
                return amount.mul(10**uint256(decimalGap));
            } else {
                return amount.div(10**uint256(decimalGap * -1));
            }
        }
    }

    function _sendTokens(address user, uint256 amount) internal override {
        reserveERC20.sendAsset(user, amount);
    }

    function isEthAggregator() external pure override returns (bool) {
        return false;
    }

    function addLiquidity(uint256 amount)
        external
        isSafeSupply
        returns (bool success)
    {
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        success = _addLiquidity(amount);
    }

    function _reserveAsset(uint256 reserveAmountRatioE8) internal override {
        uint256 amount = collateralToken
            .balanceOf(address(this))
            .mul(reserveAmountRatioE8)
            .div(10**decimals);
        require(
            collateralToken.transfer(address(reserveERC20), amount),
            "ERROR: RenewMaturity Cannot reserve collateral token"
        );
    }

    function _issueBonds(uint256 bondgroupID, uint256 amount)
        internal
        override
    {
        ERC20BondMakerInterface bm = ERC20BondMakerInterface(
            address(bondMaker)
        );
        bm.issueNewBonds(bondgroupID, _applyDecimalGap(amount, false));
    }

    function _getCollateralAmount() internal view override returns (uint256) {
        return
            collateralToken.balanceOf(address(this)).sub(
                totalReceivedCollateral[currentTerm]
            );
    }

    function getCollateralDecimal() external view override returns (int16) {
        return int16(decimalGap + decimals);
    }

    function getCollateralAmount() external view override returns (uint256) {
        return
            collateralToken.balanceOf(address(this)).sub(
                totalReceivedCollateral[currentTerm]
            );
    }

    function getReserveAddress() external view override returns (address) {
        return address(reserveERC20);
    }
}
