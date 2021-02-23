// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;
import "./SimpleAggregatorCollateralizedEth.sol";
pragma experimental ABIEncoderV2;

contract testSimpleAggregatorCollateralizedEth is SimpleAggregatorCollateralizedEth {
    event Number(uint256 num);

    constructor(
        LatestPriceOracleInterface _ethOracle,
        BondPricerWithAcceptableMaturity _pricer,
        SimpleStrategyInterface strategy,
        ERC20 _rewardToken,
        BondRegistratorInterface _registrator,
        ExchangeInterface exchangeAddress,
        VolatilityOracleInterface _volOracle,
        uint64 _priceUnit
    )
        SimpleAggregatorCollateralizedEth(
            _ethOracle,
            _pricer,
            strategy,
            _rewardToken,
            _registrator,
            exchangeAddress,
            _volOracle,
            _priceUnit,
            10**8
        )
    {}

    function changeIsLiquidated() public {
        liquidationData[currentTerm].isLiquidated = !liquidationData[currentTerm].isLiquidated;
    }

    /*
    function applyDecimalGap(uint256 amount, bool isDiv) external pure returns (uint256) {
        _applyDecimalGap(amount, isDiv);
    }
*/
    function updateBondGroupData() external {
        _updateBondGroupData();
    }

    function withdrawCollateral(uint256 amount) external {
        _transferETH(msg.sender, amount);
    }

    function transferBond(
        address tokenAddress,
        address to,
        uint256 amount
    ) external {
        require(IERC20(tokenAddress).transfer(to, amount), "Test Contract");
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
        shareData[index + 1].totalCollateralPerToken = uint128(_collateralPerToken);
        shareData[index + 1].totalShare = uint128(_totalShare);
    }

    function liquidateBondGroup(
        uint256 bondGroupId,
        uint32 liquidateBondNumber,
        uint64 maturity,
        uint64 priviousMaturity
    ) external {
        uint32 returnValue = _liquidateBondGroup(
            bondGroupId,
            liquidateBondNumber,
            maturity,
            priviousMaturity
        );
        emit Number(uint256(returnValue));
    }

    function addBondGroup(uint256 bondGroupId, uint256 callStrikePriceInEthUSD) external {
        _addBondGroup(bondGroupId, callStrikePriceInEthUSD);
    }

    function getSuitableBondGroup(uint256 currentPriceE8) external view returns (uint256) {
        return _getSuitableBondGroup(currentPriceE8);
    }

    function updatePriceUnit(uint256 currentPriceE8) external {
        _updatePriceUnit(currentPriceE8);
    }

    function addSuitableBondGroup(uint256 currentPriceE8) external returns (uint256) {
        return _addSuitableBondGroup(currentPriceE8);
    }
}
