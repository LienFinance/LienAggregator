// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity 0.7.1;

interface SimpleAggregatorInterface {
    struct TotalReward {
        uint64 term;
        uint64 value;
    }

    enum AggregatorPhase {BEFORE_START, ACTIVE, COOL_TIME, AFTER_MATURITY, EXPIRED}

    function renewMaturity() external;

    function removeLiquidity(uint128 amount) external returns (bool success);

    function settleTokens() external returns (uint256 unsentETH, uint256 unsentToken);

    function changeSpread() external;

    function liquidateBonds() external;

    function trancheBonds() external;

    function claimReward() external;

    function addSuitableBondGroup() external returns (uint256 bondGroupID);

    function getCollateralAddress() external view returns (address);

    function getCollateralAmount() external view returns (uint256);

    function getCollateralDecimal() external view returns (int16);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function transfer(address _to, uint256 _value) external returns (bool success);

    function balanceOf(address _owner) external view returns (uint256 balance);

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool success);

    function approve(address _spender, uint256 _value) external returns (bool success);

    function allowance(address _owner, address _spender) external view returns (uint256 remaining);

    function getExpectedBalance(address user, bool hasReservation)
        external
        view
        returns (uint256 expectedBalance);

    function getCurrentPhase() external view returns (AggregatorPhase);

    function updateStartBondGroupId() external;

    function getInfo()
        external
        view
        returns (
            address bondMaker,
            address strategy,
            address dotc,
            address bondPricerAddress,
            address oracleAddress,
            address rewardTokenAddress,
            address registratorAddress,
            address owner,
            bool reverseOracle,
            uint64 basePriceUnit,
            uint128 maxSupply
        );

    function getCurrentStatus()
        external
        view
        returns (
            uint256 term,
            int16 feeBase,
            uint32 uncheckbondGroupId,
            uint64 unit,
            uint64 trancheTime,
            bool isDanger
        );

    function getTermInfo(uint256 term)
        external
        view
        returns (
            uint64 maturity,
            uint64 solidStrikePrice,
            bytes32 SBTID
        );

    function getBondGroupIDFromTermAndPrice(uint256 term, uint256 price)
        external
        view
        returns (uint256 bondGroupID);

    function getRewardAmount(address user) external view returns (uint64);

    function getTotalRewards() external view returns (TotalReward[] memory);

    function isTotalSupplySafe() external view returns (bool);

    function getTotalUnmovedAssets() external view returns (uint256, uint256);

    function totalShareData(uint256 term)
        external
        view
        returns (uint128 totalShare, uint128 totalCollateralPerToken);

    function getCollateralPerToken(uint256 term) external view returns (uint256);

    function getBondGroupIdFromStrikePrice(uint256 term, uint256 strikePrice)
        external
        view
        returns (uint256);

    function getBalanceData(address user)
        external
        view
        returns (
            uint128 amount,
            uint64 term,
            uint64 rewardAmount
        );

    function getIssuableBondGroups() external view returns (uint256[] memory);

    function getLiquidationData(uint256 term)
        external
        view
        returns (
            bool isLiquidated,
            uint32 liquidatedBondGroupID,
            uint32 endBondGroupId
        );
}
