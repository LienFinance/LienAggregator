// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

import "./SimpleAggregator.sol";
import "../BondToken_and_GDOTC/bondMaker/BondMakerCollateralizedErc20Interface.sol";
import "./ReserveERC20.sol";

contract SimpleAggregatorCollateralizedERC20 is SimpleAggregator {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;
    // AUDIT-FIX: SAE-01
    ERC20 internal immutable collateralToken;
    // AUDIT-FIX: SAE-02
    int16 internal immutable decimalGap;
    // AUDIT-FIX: SAE-03
    ReserveERC20 internal immutable reserveERC20;

    constructor(
        LatestPriceOracleInterface _oracle,
        BondPricerWithAcceptableMaturity _pricer,
        SimpleStrategyInterface strategy,
        ERC20 _rewardToken,
        BondRegistratorInterface _registrator,
        ExchangeInterface exchangeAddress,
        ERC20 _collateralToken,
        VolatilityOracleInterface _volOracle,
        uint64 _priceUnit,
        uint64 _firstRewardRate,
        bool _reverseOracle
    )
        SimpleAggregator(
            _oracle,
            _pricer,
            strategy,
            _rewardToken,
            _registrator,
            exchangeAddress,
            _priceUnit,
            _firstRewardRate,
            _reverseOracle,
            _volOracle
        )
    {
        collateralToken = _collateralToken;
        _setPool(
            strategy,
            exchangeAddress,
            _volOracle,
            _pricer,
            _oracle,
            _collateralToken,
            _reverseOracle
        );
        decimalGap = int16(_collateralToken.decimals()) - decimals;
        reserveERC20 = new ReserveERC20(_collateralToken);
        // AUDIT-FIX: SAE-04
        require(address(_collateralToken) != address(0), "collateralAddress cannot be zero");
    }

    function _setPool(
        SimpleStrategyInterface _strategy,
        ExchangeInterface _exchange,
        VolatilityOracleInterface _volOracle,
        BondPricerInterface _pricer,
        LatestPriceOracleInterface _oracle,
        ERC20 _collateralToken,
        bool _reverseOracle
    ) internal {
        BondMakerInterface _bondMaker = _exchange.bondMakerAddress();
        _collateralToken.approve(address(_bondMaker), uint256(-1));
        _collateralToken.approve(address(_exchange), uint256(-1));
        int16 feeBaseE4 = _strategy.getCurrentSpread(msg.sender, address(_oracle), _reverseOracle);
        currentFeeBase = feeBaseE4;
        _exchange.createVsBondPool(_bondMaker, _volOracle, _pricer, _pricer, feeBaseE4);

        _exchange.createVsErc20Pool(ERC20(_collateralToken), _oracle, _pricer, feeBaseE4, true);

        _exchange.createVsErc20Pool(ERC20(_collateralToken), _oracle, _pricer, feeBaseE4, false);
    }

    function changeSpread() public override {
        // AUDIT-FIX: SAE-05
        int16 _currentFeeBase = STRATEGY.getCurrentSpread(OWNER, address(ORACLE), REVERSE_ORACLE);

        require(_currentFeeBase < 1000 && _currentFeeBase > 5, "Invalid feebase");
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

        bytes32 poolIDBond = DOTC.generateVsBondPoolID(address(this), address(BONDMAKER));

        DOTC.updateVsErc20Pool(poolIDTokenSell, ORACLE, BOND_PRICER, _currentFeeBase);

        DOTC.updateVsErc20Pool(poolIDTokenBuy, ORACLE, BOND_PRICER, _currentFeeBase);

        DOTC.updateVsBondPool(poolIDBond, volOracle, BOND_PRICER, BOND_PRICER, _currentFeeBase);
        currentFeeBase = _currentFeeBase;
    }

    /**
     * @notice Receive ERC20 token, then call _addLiquidity
     */
    function addLiquidity(uint256 amount) external isSafeSupply returns (bool success) {
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        success = _addLiquidity(amount);
    }

    function _sendTokens(address user, uint256 amount) internal override {
        reserveERC20.sendAsset(user, amount);
    }

    function _reserveAsset(uint256 collateralPerTokenE8) internal override {
        uint256 amount = _applyDecimalGap(
            uint256(totalUnremovedTokens[currentTerm]).mul(collateralPerTokenE8).div(10**decimals),
            false
        );
        require(
            collateralToken.transfer(address(reserveERC20), amount),
            "ERROR: RenewMaturity Cannot reserve collateral token"
        );
    }

    function _issueBonds(uint256 bondgroupID, uint256 amount) internal override {
        // ERC20 bond maker has different interface from ETH bond maker

        BondMakerCollateralizedErc20Interface bm = BondMakerCollateralizedErc20Interface(
            address(BONDMAKER)
        );

        bm.issueNewBonds(bondgroupID, _applyDecimalGap(amount, false).mul(1002).div(1000));
    }

    function getCollateralAddress() external view override returns (address) {
        return address(collateralToken);
    }

    /**
     * @dev Fill up decimal gap between collateral token and share token(decimal: 8)
     */
    function _applyDecimalGap(uint256 amount, bool isDiv) internal view override returns (uint256) {
        if (isDiv) {
            if (decimalGap < 0) {
                return amount.mul(10**uint256(decimalGap * -1));
            } else {
                return amount.div(10**uint256(decimalGap));
            }
        } else {
            if (decimalGap < 0) {
                return amount.div(10**uint256(decimalGap * -1));
            } else {
                return amount.mul(10**uint256(decimalGap));
            }
        }
    }

    /**
     * @notice Get available collateral amount in this term
     */
    function getCollateralAmount() public view override returns (uint256) {
        return collateralToken.balanceOf(address(this)).sub(totalReceivedCollateral[currentTerm]);
    }

    function getCollateralDecimal() external view override returns (int16) {
        return int16(decimalGap + decimals);
    }

    function getReserveAddress() external view override returns (address) {
        return address(reserveERC20);
    }
}
