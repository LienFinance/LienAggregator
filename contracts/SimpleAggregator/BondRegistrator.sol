// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

import "../BondToken_and_GDOTC/bondMaker/BondMakerInterface.sol";
import "../Interfaces/BondRegistratorInterface.sol";

contract BondRegistrator is BondRegistratorInterface {
    function getFnMap(Points[] memory points)
        public
        override
        pure
        returns (bytes memory)
    {
        uint256[] memory polyline = _zipLines(points);
        return abi.encode(polyline);
    }

    function _zipLines(Points[] memory points)
        internal
        pure
        returns (uint256[] memory lines)
    {
        lines = new uint256[](points.length);
        for (uint256 i = 0; i < points.length; i++) {
            uint256 x1U256 = uint256(points[i].x1) << (64 + 64 + 64); // uint64
            uint256 y1U256 = uint256(points[i].y1) << (64 + 64); // uint64
            uint256 x2U256 = uint256(points[i].x2) << 64; // uint64
            uint256 y2U256 = uint256(points[i].y2); // uint64
            uint256 zip = x1U256 | y1U256 | x2U256 | y2U256;
            lines[i] = zip;
        }
    }

    /**
     * @notice Create SBT function mapping and register new SBT
     */
    function registerSBT(
        BondMakerInterface bondMaker,
        uint64 sbtStrikePrice,
        uint64 maturity
    ) public override returns (bytes32) {
        Points[] memory SBTPoints = new Points[](2);
        SBTPoints[0] = Points(0, 0, sbtStrikePrice, sbtStrikePrice);
        SBTPoints[1] = Points(
            sbtStrikePrice,
            sbtStrikePrice,
            sbtStrikePrice * 2,
            sbtStrikePrice
        );
        return registerBond(bondMaker, SBTPoints, maturity);
    }

    /**
     * @notice Create exotic option function mappings and register bonds, then register new bond group
     * @param SBTId SBT should be already registered and use SBT bond ID
     */
    function registerBondGroup(
        BondMakerInterface bondMaker,
        uint256 callStrikePrice,
        uint64 sbtStrikePrice,
        uint64 maturity,
        bytes32 SBTId
    ) public override returns (uint256 bondGroupId) {
        bytes32[] memory bondIds = new bytes32[](4);
        uint64 lev2EndPoint = uint64(callStrikePrice * 2) - sbtStrikePrice;
        uint64 maxProfitVolShort = uint64(
            (callStrikePrice - sbtStrikePrice) / 2
        );
        bondIds[0] = SBTId;
        {
            Points[] memory CallPoints = new Points[](2);
            CallPoints[0] = Points(0, 0, uint64(callStrikePrice), 0);
            CallPoints[1] = Points(
                uint64(callStrikePrice),
                0,
                uint64(callStrikePrice * 2),
                uint64(callStrikePrice)
            );
            bondIds[1] = registerBond(bondMaker, CallPoints, maturity);
        }
        {
            Points[] memory Lev2Points = new Points[](3);
            Lev2Points[0] = Points(0, 0, sbtStrikePrice, 0);
            Lev2Points[1] = Points(
                sbtStrikePrice,
                0,
                lev2EndPoint,
                uint64(callStrikePrice - sbtStrikePrice)
            );
            Lev2Points[2] = Points(
                lev2EndPoint,
                uint64(callStrikePrice - sbtStrikePrice),
                lev2EndPoint + sbtStrikePrice,
                uint64(callStrikePrice - sbtStrikePrice)
            );
            bondIds[2] = registerBond(bondMaker, Lev2Points, maturity);
        }

        {
            Points[] memory VolShortPoints = new Points[](4);
            VolShortPoints[0] = Points(0, 0, sbtStrikePrice, 0);
            VolShortPoints[1] = Points(
                sbtStrikePrice,
                0,
                uint64(callStrikePrice),
                maxProfitVolShort
            );
            VolShortPoints[2] = Points(
                uint64(callStrikePrice),
                maxProfitVolShort,
                lev2EndPoint,
                0
            );
            VolShortPoints[3] = Points(
                lev2EndPoint,
                0,
                lev2EndPoint + sbtStrikePrice,
                0
            );

            bondIds[3] = registerBond(bondMaker, VolShortPoints, maturity);
        }
        return bondMaker.registerNewBondGroup(bondIds, uint256(maturity));
    }

    /**
     * @notice Register bond token if same bond does not exist. If exists, return bondID
     */
    function registerBond(
        BondMakerInterface bondMaker,
        Points[] memory points,
        uint256 maturity
    ) public override returns (bytes32) {
        bytes memory fnMap = getFnMap(points);
        bytes32 bondId = bondMaker.generateBondID(maturity, fnMap);
        (address bondAddress, , , ) = bondMaker.getBond(bondId);
        if (bondAddress != address(0)) {
            return bondId;
        }
        bondMaker.registerNewBond(maturity, fnMap);
        return bondId;
    }
}
