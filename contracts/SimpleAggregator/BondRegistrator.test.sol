// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity 0.7.1;
import "./BondRegistrator.sol";

contract testBondRegistrator is BondRegistrator {
    event Bytes32(bytes32 id);
    event Number(uint256 num);

    function _registerSBT(
        BondMakerInterface bondMaker,
        uint64 sbtStrikePrice,
        uint64 maturity
    ) external {
        bytes32 bondId = registerSBT(bondMaker, sbtStrikePrice, maturity);
        emit Bytes32(bondId);
    }

    function _registerBondGroup(
        BondMakerInterface bondMaker,
        uint256 callStrikePrice,
        uint64 sbtStrikePrice,
        uint64 maturity,
        bytes32 SBTId
    ) external {
        uint256 bondGroupID =
            registerBondGroup(
                bondMaker,
                callStrikePrice,
                sbtStrikePrice,
                maturity,
                SBTId
            );
        emit Number(bondGroupID);
    }

    function _registerBond(
        BondMakerInterface bondMaker,
        uint64[] memory pointsInUint,
        uint256 maturity
    ) external {
        Points[] memory points = new Points[](pointsInUint.length / 4);
        for (uint256 i = 0; i < pointsInUint.length / 4; i++) {
            points[i] = Points(
                pointsInUint[i * 4],
                pointsInUint[i * 4 + 1],
                pointsInUint[i * 4 + 2],
                pointsInUint[i * 4 + 3]
            );
        }
        bytes32 bondId = registerBond(bondMaker, points, maturity);
        emit Bytes32(bondId);
    }
}
