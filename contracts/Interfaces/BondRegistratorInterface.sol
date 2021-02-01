// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity 0.7.1;
import "../BondToken_and_GDOTC/bondMaker/BondMakerInterface.sol";

interface BondRegistratorInterface {
    struct Points {
        uint64 x1;
        uint64 y1;
        uint64 x2;
        uint64 y2;
    }

    function getFnMap(Points[] memory points)
        external
        pure
        returns (bytes memory fnMap);

    function registerSBT(
        BondMakerInterface bondMaker,
        uint64 sbtStrikePrice,
        uint64 maturity
    ) external returns (bytes32);

    function registerBondGroup(
        BondMakerInterface bondMaker,
        uint256 callStrikePrice,
        uint64 sbtStrikePrice,
        uint64 maturity,
        bytes32 SBTId
    ) external returns (uint256 bondGroupId);

    function registerBond(
        BondMakerInterface bondMaker,
        Points[] memory points,
        uint256 maturity
    ) external returns (bytes32);
}
