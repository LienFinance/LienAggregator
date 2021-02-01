// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;
import "./SimpleAggregatorCollateralizedERC20.sol";

contract testSimpleAggregatorCollateralizedERC20 is
    SimpleAggregatorCollateralizedERC20
{
    constructor(
        LatestPriceOracleInterface _oracle,
        BondPricerWithAcceptableMaturity _pricer,
        SimpleStrategyInterface strategy,
        ERC20 _rewardToken,
        BondRegistratorInterface _registrator,
        ExchangeInterface exchangeAddress,
        ERC20 _collateralAddress,
        VolatilityOracleInterface _volOracle,
        uint64 _priceUnit,
        uint64 _firstRewardRate,
        bool _reverseOracle
    )
        SimpleAggregatorCollateralizedERC20(
            _oracle,
            _pricer,
            strategy,
            _rewardToken,
            _registrator,
            exchangeAddress,
            _collateralAddress,
            _volOracle,
            _priceUnit,
            10**12,
            _reverseOracle
        )
    {}

    function changeIsLiquidated() public {
        liquidationData[currentTerm].isLiquidated = !liquidationData[
            currentTerm
        ]
            .isLiquidated;
    }

    function applyDecimalGap(uint256 amount, bool isDiv)
        external
        view
        returns (uint256)
    {
        _applyDecimalGap(amount, isDiv);
    }

    function updateBondGroupData() external {
        _updateBondGroupData();
    }

    function addToken(address user, uint256 amount) public {
        balance[user].balance = uint128(amount);
        shareData[currentTerm + 1].totalShare =
            shareData[currentTerm + 1].totalShare +
            uint128(amount);
    }

    function insertData(
        uint256 index,
        uint256 _collateralPerToken,
        uint256 _totalShare,
        uint256
    ) public {
        shareData[index + 1].totalCollateralPerToken = uint128(
            _collateralPerToken
        );
        shareData[index + 1].totalShare = uint128(_totalShare);
    }

    function withdrawCollateral(uint256 amount) external {
        collateralToken.transfer(msg.sender, amount);
    }

    function liquidateBondGroup(
        uint256 bondGroupId,
        uint32 liquidateBondNumber,
        uint64 maturity,
        uint64 priviousMaturity
    ) external {
        uint32 returnValue =
            _liquidateBondGroup(
                bondGroupId,
                liquidateBondNumber,
                maturity,
                priviousMaturity
            );
        emit Number(uint256(returnValue));
    }

    function transferBond(
        address tokenAddress,
        address to,
        uint256 amount
    ) external {
        require(
            IERC20(tokenAddress).transfer(to, amount),
            "Test Contract: Insufficient Balance Of Bond Token"
        );
    }

    function addBondGroup(uint256 bondGroupId, uint256 callStrikePriceInEthUSD)
        external
    {
        _addBondGroup(bondGroupId, callStrikePriceInEthUSD);
    }

    function getSuitableBondGroup(uint256 currentPriceE8)
        external
        view
        returns (uint256)
    {
        return _getSuitableBondGroup(currentPriceE8);
    }

    function updatePriceUnit(uint256 currentPriceE8) external {
        _updatePriceUnit(currentPriceE8);
    }

    function addSuitableBondGroup(uint256 currentPriceE8)
        external
        returns (uint256)
    {
        return _addSuitableBondGroup(currentPriceE8);
    }
}
