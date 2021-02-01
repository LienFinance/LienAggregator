// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "../util/TransferETH.sol"; // this contract has payable function
import "./BondMaker.sol";
import "../bondTokenName/BondTokenNameInterface.sol";

contract BondMakerCollateralizedEth is BondMaker, TransferETH {
    address private constant ETH = address(0);

    BondTokenNameInterface internal immutable BOND_TOKEN_NAMER;
    BondTokenFactory internal immutable BOND_TOKEN_FACTORY;

    constructor(
        PriceOracleInterface oracleAddress,
        address feeTaker,
        BondTokenNameInterface bondTokenNamerAddress,
        BondTokenFactory bondTokenFactoryAddress,
        uint256 maturityScale
    ) BondMaker(oracleAddress, feeTaker, maturityScale, 8, 8) {
        require(
            address(bondTokenNamerAddress) != address(0),
            "bondTokenNamerAddress should be non-zero address"
        );
        BOND_TOKEN_NAMER = bondTokenNamerAddress;
        require(
            address(bondTokenFactoryAddress) != address(0),
            "bondTokenFactoryAddress should be non-zero address"
        );
        BOND_TOKEN_FACTORY = bondTokenFactoryAddress;
    }

    function issueNewBonds(uint256 bondGroupID)
        public
        payable
        returns (uint256 bondAmount)
    {
        return _issueNewBonds(bondGroupID, msg.value);
    }

    function _createNewBondToken(uint256 maturity, bytes memory fnMap)
        internal
        override
        returns (BondTokenInterface)
    {
        (string memory symbol, string memory name) =
            _getBondTokenName(maturity, fnMap);
        address bondAddress =
            BOND_TOKEN_FACTORY.createBondToken(
                ETH,
                name,
                symbol,
                DECIMALS_OF_BOND
            );
        return BondTokenInterface(bondAddress);
    }

    function _getBondTokenName(uint256 maturity, bytes memory fnMap)
        internal
        view
        virtual
        returns (string memory symbol, string memory name)
    {
        bytes32 fnMapID = generateFnMapID(fnMap);
        LineSegment[] memory segments = _registeredFnMap[fnMapID];
        uint64 sbtStrikePrice = _getSbtStrikePrice(segments);
        uint64 lbtStrikePrice = _getLbtStrikePrice(segments);
        uint64 sbtStrikePriceE0 =
            sbtStrikePrice / (uint64(10)**DECIMALS_OF_ORACLE_PRICE);
        uint64 lbtStrikePriceE0 =
            lbtStrikePrice / (uint64(10)**DECIMALS_OF_ORACLE_PRICE);

        if (sbtStrikePrice != 0) {
            return
                BOND_TOKEN_NAMER.genBondTokenName(
                    "SBT",
                    "SBT",
                    maturity,
                    sbtStrikePriceE0
                );
        } else if (lbtStrikePrice != 0) {
            return
                BOND_TOKEN_NAMER.genBondTokenName(
                    "LBT",
                    "LBT",
                    maturity,
                    lbtStrikePriceE0
                );
        } else {
            return
                BOND_TOKEN_NAMER.genBondTokenName(
                    "IMT",
                    "Immortal Option",
                    maturity,
                    0
                );
        }
    }

    function _collateralAddress() internal pure override returns (address) {
        return address(0);
    }

    function _getCollateralDecimals() internal pure override returns (uint8) {
        return 18;
    }

    function _sendCollateralTo(address receiver, uint256 amount)
        internal
        override
    {
        _transferETH(payable(receiver), amount);
    }
}
