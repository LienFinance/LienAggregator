// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;
import "../BondToken_and_GDOTC/bondMaker/BondMakerInterface.sol";

interface SimpleStrategyInterface {
    function calcNextMaturity() external view returns (uint256 nextTimeStamp);

    function calcCallStrikePrice(
        uint256 currentPriceE8,
        uint64 priceUnit,
        bool isReversedOracle
    ) external pure returns (uint256 callStrikePrice);

    function calcRoundPrice(
        uint256 price,
        uint64 priceUnit,
        uint8 divisor
    ) external pure returns (uint256 roundedPrice);

    function getTrancheBonds(
        BondMakerInterface bondMaker,
        address aggregatorAddress,
        uint256 issueBondGroupIdOrStrikePrice,
        uint256 price,
        uint256[] calldata bondGroupList,
        uint64 priceUnit,
        bool isReversedOracle
    )
        external
        view
        returns (
            uint256 issueAmount,
            uint256 ethAmount,
            uint256[2] memory IDAndAmountOfBurn
        );

    function getCurrentStrikePrice(
        uint256 currentPriceE8,
        uint64 priceUnit,
        bool isReversedOracle
    ) external pure returns (uint256);

    function getCurrentSpread(
        address owner,
        address oracleAddress,
        bool isReversedOracle
    ) external view returns (int16);

    function registerCurrentFeeBase(
        int16 currentFeeBase,
        uint256 currentCollateralPerToken,
        uint256 nextCollateralPerToken,
        address owner,
        address oracleAddress,
        bool isReversedOracle
    ) external;
}
