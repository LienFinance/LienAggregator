// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

contract fnMapGenerator {
    function zipLines(uint64[] memory points)
        internal
        pure
        returns (uint256[] memory lines)
    {
        lines = new uint256[](points.length / 4);
        for (uint256 i = 0; i < points.length / 4; i++) {
            uint256 x1U256 = uint256(points[4 * i]) << (64 + 64 + 64); // uint64
            uint256 y1U256 = uint256(points[4 * i + 1]) << (64 + 64); // uint64
            uint256 x2U256 = uint256(points[4 * i + 2]) << 64; // uint64
            uint256 y2U256 = uint256(points[4 * i + 3]); // uint64
            uint256 zip = x1U256 | y1U256 | x2U256 | y2U256;
            lines[i] = zip;
        }
    }

    function getFnMap(uint64[] memory points)
        public
        view
        returns (bytes memory fnMap)
    {
        uint256[] memory polyline = zipLines(points);
        return abi.encode(polyline);
    }
}
