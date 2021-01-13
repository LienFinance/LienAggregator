// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

contract testBondMaker2 {
    mapping(bytes32 => bytes32) bondIDTofnMapID;
    mapping(bytes32 => bytes) fnMapIDTofnMap;
    mapping(bytes32 => uint64) bondIDToSolidStrikePrice;
    uint256 _maturity;

    constructor() {
        _maturity = block.timestamp + 1000000;
    }

    event getBondID(bytes32 bondID);

    function registerBond(uint64[] memory points, uint64 solidStrikePrice)
        public
        returns (bytes32)
    {
        uint256[] memory lines = zipLines(points);

        bytes memory fnMap = abi.encode(lines);
        bytes32 fnMapID = keccak256(fnMap);
        bytes32 bondID = keccak256(abi.encodePacked(_maturity, points));

        bondIDToSolidStrikePrice[bondID] = solidStrikePrice;
        bondIDTofnMapID[bondID] = fnMapID;
        fnMapIDTofnMap[fnMapID] = fnMap;
        emit getBondID(bondID);
    }

    function getBond(bytes32 bondID)
        public
        view
        returns (
            address bondTokenAddress,
            uint256 maturity,
            uint64 solidStrikePrice,
            bytes32 fnMapID
        )
    {
        bondTokenAddress = address(0);
        maturity = _maturity;
        solidStrikePrice = bondIDToSolidStrikePrice[bondID];
        fnMapID = bondIDTofnMapID[bondID];
    }

    function getFnMap(bytes32 fnMapID) public view returns (bytes memory) {
        return fnMapIDTofnMap[fnMapID];
    }

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
}
