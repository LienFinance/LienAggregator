// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "../bondMaker/BondMakerInterface.sol";
import "../util/Polyline.sol";
import {BondType} from "./Enums.sol";

contract DetectBondShape is Polyline {
    /**
     * @notice Detect bond type by polyline of bond.
     * @param bondID bondID of target bond token
     * @param submittedType if this parameter is BondType.NONE, this function checks up all bond types. Otherwise this function checks up only one bond type.
     * @param success whether bond detection succeeded or notice
     * @param points coodinates of polyline which is needed for price calculation
     **/
    function getBondTypeByID(
        BondMakerInterface bondMaker,
        bytes32 bondID,
        BondType submittedType
    )
        public
        view
        returns (
            bool success,
            BondType,
            uint256[] memory points
        )
    {
        (, , , bytes32 fnMapID) = bondMaker.getBond(bondID);
        bytes memory fnMap = bondMaker.getFnMap(fnMapID);
        return _getBondType(fnMap, submittedType);
    }

    /**
     * @notice Detect bond type by polyline of bond.
     * @param fnMap Function mapping of target bond token
     * @param submittedType If this parameter is BondType.NONE, this function checks up all bond types. Otherwise this function checks up only one bond type.
     * @param success Whether bond detection succeeded or not
     * @param points Coodinates of polyline which are needed for price calculation
     **/
    function getBondType(bytes calldata fnMap, BondType submittedType)
        external
        pure
        returns (
            bool success,
            BondType,
            uint256[] memory points
        )
    {
        uint256[] memory polyline = decodePolyline(fnMap);
        LineSegment[] memory segments = new LineSegment[](polyline.length);
        for (uint256 i = 0; i < polyline.length; i++) {
            segments[i] = unzipLineSegment(polyline[i]);
        }
        assertPolyline(segments);

        return _getBondType(fnMap, submittedType);
    }

    function _getBondType(bytes memory fnMap, BondType submittedType)
        internal
        pure
        returns (
            bool success,
            BondType,
            uint256[] memory points
        )
    {
        if (submittedType == BondType.NONE) {
            (success, points) = _isSBT(fnMap);
            if (success) {
                return (success, BondType.PURE_SBT, points);
            }

            (success, points) = _isSBTShape(fnMap);
            if (success) {
                return (success, BondType.SBT_SHAPE, points);
            }

            (success, points) = _isLBTShape(fnMap);
            if (success) {
                return (success, BondType.LBT_SHAPE, points);
            }

            (success, points) = _isTriangle(fnMap);
            if (success) {
                return (success, BondType.TRIANGLE, points);
            }

            return (false, BondType.NONE, points);
        } else if (submittedType == BondType.PURE_SBT) {
            (success, points) = _isSBT(fnMap);
            if (success) {
                return (success, BondType.PURE_SBT, points);
            }
        } else if (submittedType == BondType.SBT_SHAPE) {
            (success, points) = _isSBTShape(fnMap);
            if (success) {
                return (success, BondType.SBT_SHAPE, points);
            }
        } else if (submittedType == BondType.LBT_SHAPE) {
            (success, points) = _isLBTShape(fnMap);
            if (success) {
                return (success, BondType.LBT_SHAPE, points);
            }
        } else if (submittedType == BondType.TRIANGLE) {
            (success, points) = _isTriangle(fnMap);
            if (success) {
                return (success, BondType.TRIANGLE, points);
            }
        }

        return (false, BondType.NONE, points);
    }

    function _isLBTShape(bytes memory fnMap)
        internal
        pure
        returns (bool isOk, uint256[] memory points)
    {
        uint256[] memory zippedLines = decodePolyline(fnMap);
        if (zippedLines.length != 2) {
            return (false, points);
        }
        LineSegment memory secondLine = unzipLineSegment(zippedLines[1]);
        if (
            secondLine.left.x != 0 &&
            secondLine.left.y == 0 &&
            secondLine.right.x > secondLine.left.x &&
            secondLine.right.y != 0
        ) {
            uint256[] memory _lines = new uint256[](3);
            _lines[0] = secondLine.left.x;
            _lines[1] = secondLine.right.x;
            _lines[2] = secondLine.right.y;
            return (true, _lines);
        }
        return (false, points);
    }

    function _isTriangle(bytes memory fnMap)
        internal
        pure
        returns (bool isOk, uint256[] memory points)
    {
        uint256[] memory zippedLines = decodePolyline(fnMap);
        if (zippedLines.length != 4) {
            return (false, points);
        }
        LineSegment memory secondLine = unzipLineSegment(zippedLines[1]);
        LineSegment memory thirdLine = unzipLineSegment(zippedLines[2]);
        LineSegment memory forthLine = unzipLineSegment(zippedLines[3]);
        if (
            secondLine.left.x != 0 &&
            secondLine.left.y == 0 &&
            secondLine.right.x > secondLine.left.x &&
            secondLine.right.y != 0 &&
            thirdLine.right.x > secondLine.right.x &&
            thirdLine.right.y == 0 &&
            forthLine.right.x > thirdLine.right.x &&
            forthLine.right.y == 0
        ) {
            uint256[] memory _lines = new uint256[](4);
            _lines[0] = secondLine.left.x;
            _lines[1] = secondLine.right.x;
            _lines[2] = secondLine.right.y;
            _lines[3] = thirdLine.right.x;
            return (true, _lines);
        }
        return (false, points);
    }

    function _isSBTShape(bytes memory fnMap)
        internal
        pure
        returns (bool isOk, uint256[] memory points)
    {
        uint256[] memory zippedLines = decodePolyline(fnMap);
        if (zippedLines.length != 3) {
            return (false, points);
        }
        LineSegment memory secondLine = unzipLineSegment(zippedLines[1]);
        LineSegment memory thirdLine = unzipLineSegment(zippedLines[2]);
        if (
            secondLine.left.x != 0 &&
            secondLine.left.y == 0 &&
            secondLine.right.x > secondLine.left.x &&
            secondLine.right.y != 0 &&
            thirdLine.right.x > secondLine.right.x &&
            thirdLine.right.y == secondLine.right.y
        ) {
            uint256[] memory _lines = new uint256[](3);
            _lines[0] = secondLine.left.x;
            _lines[1] = secondLine.right.x;
            _lines[2] = secondLine.right.y;
            return (true, _lines);
        }
        return (false, points);
    }

    function _isSBT(bytes memory fnMap) internal pure returns (bool isOk, uint256[] memory points) {
        uint256[] memory zippedLines = decodePolyline(fnMap);
        if (zippedLines.length != 2) {
            return (false, points);
        }
        LineSegment memory secondLine = unzipLineSegment(zippedLines[1]);

        if (
            secondLine.left.x != 0 &&
            secondLine.left.y == secondLine.left.x &&
            secondLine.right.x > secondLine.left.x &&
            secondLine.right.y == secondLine.left.y
        ) {
            uint256[] memory _lines = new uint256[](1);
            _lines[0] = secondLine.left.x;
            return (true, _lines);
        }

        return (false, points);
    }
}
