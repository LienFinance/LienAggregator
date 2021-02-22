// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

import "../oracle/PriceOracleInterface.sol";
import "../bondMaker/BondMakerInterface.sol";
import "../util/Polyline.sol";

contract BondMakerHelper is Polyline {
    event LogRegisterSbt(bytes32 bondID);
    event LogRegisterLbt(bytes32 bondID);
    event LogRegisterBondAndBondGroup(uint256 indexed bondGroupID, bytes32[] bondIDs);

    function registerSbt(
        address bondMakerAddress,
        uint64 strikePrice,
        uint256 maturity
    ) external returns (bytes32 bondID) {
        require(strikePrice != 0, "the strike price must be non-zero");
        require(strikePrice <= uint64(-1) / 2, "the strike price is too large");

        BondMakerInterface bondMaker = BondMakerInterface(bondMakerAddress);
        try bondMaker.oracleAddress() returns (PriceOracleInterface oracle) {
            uint256 spotPrice = oracle.latestPrice();
            require(
                strikePrice >= spotPrice / 10 && strikePrice <= spotPrice * 10,
                "must be 0.1 <= S/K <= 10"
            );
        } catch {}

        bytes memory fnMap = _getSbtFnMap(strikePrice);
        (bondID, , ) = bondMaker.registerNewBond(maturity, fnMap);

        emit LogRegisterSbt(bondID);
    }

    function registerLbt(
        address bondMakerAddress,
        uint64 strikePrice,
        uint256 maturity
    ) external returns (bytes32 bondID) {
        require(strikePrice != 0, "the strike price must be non-zero");
        require(strikePrice <= uint64(-1) / 2, "the strike price is too large");

        BondMakerInterface bondMaker = BondMakerInterface(bondMakerAddress);
        try bondMaker.oracleAddress() returns (PriceOracleInterface oracle) {
            uint256 spotPrice = oracle.latestPrice();
            require(
                strikePrice >= spotPrice / 10 && strikePrice <= spotPrice * 10,
                "must be 0.1 <= S/K <= 10"
            );
        } catch {}

        bytes memory fnMap = _getLbtFnMap(strikePrice);
        (bondID, , ) = bondMaker.registerNewBond(maturity, fnMap);

        emit LogRegisterLbt(bondID);
    }

    function registerSbtAndLbtAndBondGroup(
        address bondMakerAddress,
        uint64 strikePrice,
        uint256 maturity
    ) external returns (uint256 bondGroupID) {
        require(strikePrice != 0, "the SBT strike price must be non-zero");

        BondMakerInterface bondMaker = BondMakerInterface(bondMakerAddress);
        try bondMaker.oracleAddress() returns (PriceOracleInterface oracle) {
            uint256 spotPrice = oracle.latestPrice();
            require(
                strikePrice >= spotPrice / 10 && strikePrice <= spotPrice * 10,
                "must be 0.1 <= S/K <= 10"
            );
        } catch {}

        bytes[] memory fnMaps = _getSbtAndLbtFnMap(strikePrice);
        bondGroupID = _registerBondAndBondGroup(bondMakerAddress, fnMaps, maturity);
    }

    function registerExoticBondAndBondGroup(
        address bondMakerAddress,
        uint64 sbtstrikePrice,
        uint64 lbtStrikePrice,
        uint256 maturity
    ) external returns (uint256 bondGroupID) {
        require(sbtstrikePrice != 0, "the SBT strike price must be non-zero");

        BondMakerInterface bondMaker = BondMakerInterface(bondMakerAddress);
        try bondMaker.oracleAddress() returns (PriceOracleInterface oracle) {
            uint256 spotPrice = oracle.latestPrice();
            require(
                sbtstrikePrice >= spotPrice / 10 && sbtstrikePrice <= spotPrice * 10,
                "must be 0.1 <= S/K <= 10"
            );
            require(
                lbtStrikePrice >= spotPrice / 10 && lbtStrikePrice <= spotPrice * 10,
                "must be 0.1 <= S/K <= 10"
            );
        } catch {}

        bytes[] memory fnMaps = _getExoticFnMap(sbtstrikePrice, lbtStrikePrice);
        bondGroupID = _registerBondAndBondGroup(bondMakerAddress, fnMaps, maturity);
    }

    function registerBondAndBondGroup(
        address bondMakerAddress,
        bytes[] memory fnMaps,
        uint256 maturity
    ) external returns (uint256 bondGroupID) {
        bondGroupID = _registerBondAndBondGroup(bondMakerAddress, fnMaps, maturity);
    }

    function getSbtFnMap(uint64 strikePrice) external pure returns (bytes memory fnMap) {
        fnMap = _getSbtFnMap(strikePrice);
    }

    function getLbtFnMap(uint64 strikePrice) external pure returns (bytes memory fnMap) {
        fnMap = _getLbtFnMap(strikePrice);
    }

    function getSbtAndLbtFnMap(uint64 strikePrice) external pure returns (bytes[] memory fnMaps) {
        fnMaps = _getSbtAndLbtFnMap(strikePrice);
    }

    function getExoticFnMap(uint64 sbtStrikePrice, uint64 lbtStrikePrice)
        external
        pure
        returns (bytes[] memory fnMaps)
    {
        fnMaps = _getExoticFnMap(sbtStrikePrice, lbtStrikePrice);
    }

    /**
     * @dev register bonds and bond group
     */
    function _registerBondAndBondGroup(
        address bondMakerAddress,
        bytes[] memory fnMaps,
        uint256 maturity
    ) internal returns (uint256 bondGroupID) {
        require(fnMaps.length != 0, "fnMaps must be non-empty list");

        BondMakerInterface bondMaker = BondMakerInterface(bondMakerAddress);
        bytes32[] memory bondIDs = new bytes32[](fnMaps.length);
        for (uint256 j = 0; j < fnMaps.length; j++) {
            bytes32 bondID = bondMaker.generateBondID(maturity, fnMaps[j]);
            (address bondAddress, , , ) = bondMaker.getBond(bondID);
            if (bondAddress == address(0)) {
                (bytes32 returnedBondID, , ) = bondMaker.registerNewBond(maturity, fnMaps[j]);
                require(
                    returnedBondID == bondID,
                    "system error: bondID was not generated as expected"
                );
            }
            bondIDs[j] = bondID;
        }

        bondGroupID = bondMaker.registerNewBondGroup(bondIDs, maturity);

        emit LogRegisterBondAndBondGroup(bondGroupID, bondIDs);
    }

    /**
     * @return fnMaps divided into SBT and LBT
     */
    function _getSbtAndLbtFnMap(uint64 strikePrice) internal pure returns (bytes[] memory fnMaps) {
        require(strikePrice <= uint64(-1) / 2, "the strike price is too large");

        fnMaps = new bytes[](2);
        fnMaps[0] = _getSbtFnMap(strikePrice);
        fnMaps[1] = _getLbtFnMap(strikePrice);
    }

    /**
     * @return fnMaps divided into pure SBT, LBT, semi-SBT and triangle bond.
     */
    function _getExoticFnMap(uint64 sbtStrikePrice, uint64 lbtStrikePrice)
        internal
        pure
        returns (bytes[] memory fnMaps)
    {
        require(
            sbtStrikePrice < lbtStrikePrice,
            "the SBT strike price must be less than the LBT strike price"
        );
        uint64 semiSbtStrikePrice = lbtStrikePrice - sbtStrikePrice;
        require(semiSbtStrikePrice % 2 == 0, "the triangle peak must be integer");
        uint64 trianglePeak = semiSbtStrikePrice / 2;
        uint64 triangleRightmost = semiSbtStrikePrice + lbtStrikePrice;
        require(
            triangleRightmost > lbtStrikePrice,
            "the triangle rightmost must be more than the LBT strike price"
        );
        require(triangleRightmost <= uint64(-1) - sbtStrikePrice, "the strike price is too large");

        uint256[] memory semiSbtPolyline;
        {
            Point[] memory points = new Point[](3);
            points[0] = Point(sbtStrikePrice, 0);
            points[1] = Point(triangleRightmost, semiSbtStrikePrice);
            points[2] = Point(triangleRightmost + sbtStrikePrice, semiSbtStrikePrice);
            semiSbtPolyline = _calcPolyline(points);
        }

        uint256[] memory trianglePolyline;
        {
            Point[] memory points = new Point[](4);
            points[0] = Point(sbtStrikePrice, 0);
            points[1] = Point(lbtStrikePrice, trianglePeak);
            points[2] = Point(triangleRightmost, 0);
            points[3] = Point(triangleRightmost + sbtStrikePrice, 0);
            trianglePolyline = _calcPolyline(points);
        }

        fnMaps = new bytes[](4);
        fnMaps[0] = _getSbtFnMap(sbtStrikePrice);
        fnMaps[1] = _getLbtFnMap(lbtStrikePrice);
        fnMaps[2] = abi.encode(semiSbtPolyline);
        fnMaps[3] = abi.encode(trianglePolyline);
    }

    function _getSbtFnMap(uint64 strikePrice) internal pure returns (bytes memory fnMap) {
        Point[] memory points = new Point[](2);
        points[0] = Point(strikePrice, strikePrice);
        points[1] = Point(2 * strikePrice, strikePrice);
        uint256[] memory polyline = _calcPolyline(points);

        fnMap = abi.encode(polyline);
    }

    function _getLbtFnMap(uint64 strikePrice) internal pure returns (bytes memory fnMap) {
        Point[] memory points = new Point[](2);
        points[0] = Point(strikePrice, 0);
        points[1] = Point(2 * strikePrice, strikePrice);
        uint256[] memory polyline = _calcPolyline(points);

        fnMap = abi.encode(polyline);
    }

    /**
     * @dev [(x_1, y_1), (x_2, y_2), ..., (x_(n-1), y_(n-1)), (x_n, y_n)]
     *   -> [(0, 0, x_1, y_1), (x_1, y_1, x_2, y_2), ..., (x_(n-1), y_(n-1), x_n, y_n)]
     */
    function _calcPolyline(Point[] memory points)
        internal
        pure
        returns (uint256[] memory polyline)
    {
        Point memory leftPoint = Point(0, 0);
        polyline = new uint256[](points.length);
        for (uint256 i = 0; i < points.length; i++) {
            Point memory rightPoint = points[i];
            polyline[i] = zipLineSegment(LineSegment(leftPoint, rightPoint));
            leftPoint = rightPoint;
        }
    }
}
