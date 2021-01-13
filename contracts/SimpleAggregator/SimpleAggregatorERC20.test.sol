// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;
import "./SimpleAggregatorCollateralizedERC20.sol";

contract testSimpleAggregatorCollateralizedERC20 is
    SimpleAggregatorCollateralizedERC20
{
    using SafeMath for uint256;

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
        SimpleAggregatorCollateralizedERC20(
            _bondMaker,
            _oracle,
            _pricer,
            strategy,
            exchangeAddress,
            _maxSupplyDenumerator,
            _collateralAddress,
            _volOracle,
            _priceUnit
        )
    {}

    event Number(uint256 number);

    function getIssuableBondGroupIds(uint256 index)
        public
        view
        returns (uint256)
    {
        return issuableBondGroupIds[currentTerm][index];
    }

    function setSBTID(bytes32 sbtID) public {
        SBT_ID[currentTerm][0] = sbtID;
    }

    function changeIsLiquidated() public {
        liquidationData[currentTerm]
            .isLiquidated = !liquidationData[currentTerm].isLiquidated;
    }

    function setIssuableBondGroups(uint256[] memory bondGroupIds) public {
        issuableBondGroupIds[currentTerm] = bondGroupIds;
    }

    function applyDecimalGap(uint256 amount, bool isDiv)
        external
        view
        returns (uint256)
    {
        _applyDecimalGap(amount, isDiv);
    }

    function getCollateralAmountInRenewalPhase()
        external
        view
        returns (uint256)
    {
        return _getCollateralAmount();
    }

    function updateBondGroupData() external {
        _updateBondGroupData();
    }

    function getReceivedETHs(address user)
        public
        view
        returns (uint128, uint128)
    {
        return (receivedCollaterals[user].term, receivedCollaterals[user].value);
    }

    function getUnremovedTokens(address user)
        public
        view
        returns (uint128, uint128)
    {
        return (unremovedTokens[user].term, unremovedTokens[user].value);
    }

    function addToken(address user, uint256 amount) public {
        for (uint32 i = 0; i <= currentTerm; i++) {
            balance[user] = uint128(amount);
        }
    }

    function insertData(
        uint256 index,
        uint256 _ethPerToken,
        uint256 _totalShare,
        uint256 _totalSBT
    ) public {
        shareData[index + 1].totalCollateralPerToken = uint128(_ethPerToken);
        shareData[index + 1].totalShare = uint128(_totalShare);
    }

    function getLiquidatedBondIndex() public view returns (uint32) {
        return liquidationData[currentTerm].liquidatedBondGroupID;
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
}
