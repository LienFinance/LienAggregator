// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;
import "./BondMakerInterface.sol";

interface StrategyInterface {
    function isValidBondGroup(
        BondMakerInterface bondMaker,
        uint256 bondGroupId,
        uint256 currentStrikePrice,
        uint256 nextTimeStamp
    ) external view returns (bool);

    function isValidLBT(
        BondMakerInterface bondMaker,
        uint256 bondGroupId,
        uint256 currentPrice,
        uint256 solidStrikePrice,
        uint256 maturity
    ) external view returns (bool);

    function getTrancheBonds(
        BondMakerInterface bondMaker,
        address aggregatorAddress,
        uint256 baseBondGroupID,
        uint256 price,
        uint256[] calldata bondGroupList
    ) external view returns (int256[] memory);

    function getCurrentStrikePrice(
        uint256 maturity,
        uint256 currentPriceE8,
        uint256 volatilityE8
    ) external view returns (uint256);

    function getCurrentSpread() external view returns (int16);
}

interface SimpleStrategyInterface {
    function calcNextMaturity() external view returns (uint256 nextTimeStamp);

    function isValidLBT(
        BondMakerInterface bondMaker,
        uint256 bondGroupId,
        uint256 currentPrice,
        uint256 solidStrikePrice,
        uint256 maturity,
        uint32 priceUnit
    ) external view returns (bool);

    function getTrancheBonds(
        BondMakerInterface bondMaker,
        address aggregatorAddress,
        uint256 price,
        uint256[] calldata bondGroupList,
        uint32 priceUnit
    ) external view returns (int256[] memory);

    function getCurrentStrikePrice(
        uint256 maturity,
        uint256 currentPriceE8,
        uint256 volatilityE8,
        uint32 priceUnit
    ) external view returns (uint256);

    function getCurrentSpread() external view returns (int16);
}
