// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;
import "../Interfaces/BondMakerInterface.sol";
import {BondType} from "../utils/Enums.sol";
import "../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";

contract DetectBondShape {
    using SafeMath for uint256;
    using SafeMath for int256;

    /**
     * @notice Detect bond type by polyline of bond
     * @param bondID bondID of target bond token
     * @param submittedType if this parameter is BondType.NONE, this function checks up all bond types. Otherwise this function checks up only one bond type.
     * @param points coodinates of polyline which is needed for price calculation
     **/
    function getBondType(
        BondMakerInterface bondMaker,
        bytes32 bondID,
        BondType submittedType
    ) public view returns (BondType, uint256[] memory points) {
        bool success;
        (, , uint256 solidStrikePrice, bytes32 fnMapID) = bondMaker.getBond(
            bondID
        );
        bytes memory fnMap = bondMaker.getFnMap(fnMapID);
        if (submittedType == BondType.NONE) {
            (success, points) = _isSBT(solidStrikePrice);
            if (success) {
                return (BondType.PURE_SBT, points);
            }
            (success, points) = _isSBTShape(fnMap);
            if (success) {
                return (BondType.SBT_SHAPE, points);
            }

            (success, points) = _isLBTShape(fnMap);
            if (success) {
                return (BondType.LBT_SHAPE, points);
            }

            (success, points) = _isTriangle(fnMap);
            if (success) {
                return (BondType.TRIANGLE, points);
            }

            return (BondType.NONE, points);
        } else if (submittedType == BondType.PURE_SBT) {
            (success, points) = _isSBT(solidStrikePrice);
            if (success) {
                return (BondType.PURE_SBT, points);
            }
        } else if (submittedType == BondType.SBT_SHAPE) {
            (success, points) = _isSBTShape(fnMap);
            if (success) {
                return (BondType.SBT_SHAPE, points);
            }
        } else if (submittedType == BondType.LBT_SHAPE) {
            (success, points) = _isLBTShape(fnMap);
            if (success) {
                return (BondType.LBT_SHAPE, points);
            }
        } else if (submittedType == BondType.TRIANGLE) {
            (success, points) = _isTriangle(fnMap);
            if (success) {
                return (BondType.TRIANGLE, points);
            }
        }

        return (BondType.NONE, points);
    }

    /**
     * @notice unzip uint256 to uint256[4].
     */
    function unzipLineSegment(uint256 zip)
        internal
        pure
        returns (uint64[4] memory)
    {
        uint64 x1 = uint64(zip >> (64 + 64 + 64));
        uint64 y1 = uint64(zip >> (64 + 64));
        uint64 x2 = uint64(zip >> 64);
        uint64 y2 = uint64(zip);
        return [x1, y1, x2, y2];
    }

    /**
     * @notice unzip the fnMap to uint256[].
     */
    function decodePolyline(bytes memory fnMap)
        internal
        pure
        returns (uint256[] memory)
    {
        return abi.decode(fnMap, (uint256[]));
    }

    function _isLBTShape(bytes memory fnMap)
        internal
        view
        returns (bool isOk, uint256[] memory points)
    {
        uint256[] memory zippedLines = decodePolyline(fnMap);
        if (zippedLines.length != 2) {
            return (false, points);
        }
        uint64[4] memory secondLine = unzipLineSegment(zippedLines[1]);
        if (
            secondLine[0] > 0 &&
            secondLine[1] == 0 &&
            secondLine[2] > secondLine[0] &&
            secondLine[3] > 0
        ) {
            uint256[] memory _lines = new uint256[](3);
            _lines[0] = secondLine[0];
            _lines[1] = secondLine[2];
            _lines[2] = secondLine[3];
            return (true, _lines);
        }
        return (false, points);
    }

    function _isTriangle(bytes memory fnMap)
        internal
        view
        returns (bool isOk, uint256[] memory points)
    {
        uint256[] memory zippedLines = decodePolyline(fnMap);
        if (zippedLines.length != 4) {
            return (false, points);
        }
        uint64[4] memory secondLine = unzipLineSegment(zippedLines[1]);
        uint64[4] memory thirdLine = unzipLineSegment(zippedLines[2]);
        uint64[4] memory forthLine = unzipLineSegment(zippedLines[3]);
        if (
            secondLine[0] > 0 &&
            secondLine[1] == 0 &&
            secondLine[2] > secondLine[0] &&
            secondLine[3] > 0 &&
            thirdLine[2] > secondLine[2] &&
            thirdLine[3] == 0 &&
            forthLine[2] > thirdLine[2] &&
            forthLine[3] == 0
        ) {
            uint256[] memory _lines = new uint256[](4);
            _lines[0] = secondLine[0];
            _lines[1] = secondLine[2];
            _lines[2] = secondLine[3];
            _lines[3] = thirdLine[2];
            return (true, _lines);
        }
        return (false, points);
    }

    function _isSBTShape(bytes memory fnMap)
        internal
        view
        returns (bool isOk, uint256[] memory points)
    {
        uint256[] memory zippedLines = decodePolyline(fnMap);
        if (zippedLines.length != 3) {
            return (false, points);
        }
        uint64[4] memory secondLine = unzipLineSegment(zippedLines[1]);
        uint64[4] memory thirdLine = unzipLineSegment(zippedLines[2]);
        if (
            secondLine[0] > 0 &&
            secondLine[1] == 0 &&
            secondLine[2] > secondLine[0] &&
            secondLine[3] > 0 &&
            thirdLine[2] > secondLine[2] &&
            thirdLine[3] == secondLine[3]
        ) {
            uint256[] memory _lines = new uint256[](3);
            _lines[0] = secondLine[0];
            _lines[1] = secondLine[2];
            _lines[2] = secondLine[3];
            return (true, _lines);
        }
        return (false, points);
    }

    /**
     * @notice SBT can be verified by only solidStrikePrice.
     */
    function _isSBT(uint256 solidStrikePrice)
        internal
        pure
        returns (bool isOk, uint256[] memory points)
    {
        uint256[] memory _lines = new uint256[](1);
        _lines[0] = solidStrikePrice;
        return (solidStrikePrice > 0, _lines);
    }
}
