// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./BondTokenInterface.sol";
import "./OracleInterface.sol";

interface BondMakerInterface {
    event LogNewBond(
        bytes32 indexed bondID,
        address indexed bondTokenAddress,
        uint256 indexed maturity,
        bytes32 fnMapID
    );

    event LogNewBondGroup(
        uint256 indexed bondGroupID,
        uint256 indexed maturity,
        uint64 indexed sbtStrikePrice,
        bytes32[] bondIDs
    );

    event LogIssueNewBonds(
        uint256 indexed bondGroupID,
        address indexed issuer,
        uint256 amount
    );

    event LogReverseBondGroupToCollateral(
        uint256 indexed bondGroupID,
        address indexed owner,
        uint256 amount
    );

    event LogExchangeEquivalentBonds(
        address indexed owner,
        uint256 indexed inputBondGroupID,
        uint256 indexed outputBondGroupID,
        uint256 amount
    );

    event LogLiquidateBond(
        bytes32 indexed bondID,
        uint128 rateNumerator,
        uint128 rateDenominator
    );

    function issueNewBonds(uint256 bondGroupID)
        external
        payable
        returns (uint256 amount);

    function registerNewBond(uint256 maturity, bytes calldata fnMap)
        external
        returns (
            bytes32 bondID,
            address bondTokenAddress,
            bytes32 fnMapID
        );

    function registerNewBondGroup(
        bytes32[] calldata bondIDList,
        uint256 maturity
    ) external returns (uint256 bondGroupID);

    function reverseBondGroupToCollateral(uint256 bondGroupID, uint256 amount)
        external
        returns (bool success);

    function exchangeEquivalentBonds(
        uint256 inputBondGroupID,
        uint256 outputBondGroupID,
        uint256 amount,
        bytes32[] calldata exceptionBonds
    ) external returns (bool);

    function liquidateBond(uint256 bondGroupID, uint256 oracleHintID)
        external
        returns (uint256 totalPayment);

    function collateralAddress() external view returns (address);

    function oracleAddress() external view returns (PriceOracleInterface);

    function feeTaker() external view returns (address);

    function decimalsOfBond() external view returns (uint8);

    function decimalsOfOraclePrice() external view returns (uint8);

    function maturityScale() external view returns (uint256);

    function nextBondGroupID() external view returns (uint256);

    function getCollateralAmount() external view returns (uint256);

    function getBond(bytes32 bondID)
        external
        view
        returns (
            address bondAddress,
            uint256 maturity,
            uint64 solidStrikePrice,
            bytes32 fnMapID
        );

    function getFnMap(bytes32 fnMapID)
        external
        view
        returns (bytes memory fnMap);

    function getBondGroup(uint256 bondGroupID)
        external
        view
        returns (bytes32[] memory bondIDs, uint256 maturity);

    function generateFnMapID(bytes calldata fnMap)
        external
        view
        returns (bytes32 fnMapID);

    function generateBondID(uint256 maturity, bytes calldata fnMap)
        external
        view
        returns (bytes32 bondID);
}
