// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./BondMaker.sol";
import "../bondTokenName/BondTokenNameInterface.sol";
import "../../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract BondMakerCollateralizedErc20 is BondMaker {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    ERC20 internal immutable COLLATERALIZED_TOKEN;
    BondTokenNameInterface internal immutable BOND_TOKEN_NAMER;
    BondTokenFactory internal immutable BOND_TOKEN_FACTORY;

    constructor(
        ERC20 collateralizedTokenAddress,
        PriceOracleInterface oracleAddress,
        address feeTaker,
        BondTokenNameInterface bondTokenNamerAddress,
        BondTokenFactory bondTokenFactoryAddress,
        uint256 maturityScale,
        uint8 decimalsOfBond,
        uint8 decimalsOfOraclePrice
    ) BondMaker(oracleAddress, feeTaker, maturityScale, decimalsOfBond, decimalsOfOraclePrice) {
        uint8 decimalsOfCollateral = collateralizedTokenAddress.decimals();
        require(decimalsOfCollateral < 19, "the decimals of collateral must be less than 19");
        COLLATERALIZED_TOKEN = collateralizedTokenAddress;
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

    /**
     * @dev If actual sent amount differ expected amount because of protocol fee etc,
     * one cannot create the bond collateralized the token.
     * The reason is that it is ambiguous how much this contract returns the collateralized token
     * from the bond owners when the bond is liquidated.
     */
    function issueNewBonds(uint256 bondGroupID, uint256 amount)
        public
        returns (uint256 bondAmount)
    {
        uint256 allowance = COLLATERALIZED_TOKEN.allowance(msg.sender, address(this));
        require(amount <= allowance, "insufficient allowance");
        uint256 receivedAmount = _receiveCollateralFrom(msg.sender, amount);
        return _issueNewBonds(bondGroupID, receivedAmount);
    }

    function _createNewBondToken(uint256 maturity, bytes memory fnMap)
        internal
        override
        returns (BondTokenInterface)
    {
        (string memory symbol, string memory name) = _getBondTokenName(maturity, fnMap);
        address bondAddress = BOND_TOKEN_FACTORY.createBondToken(
            address(COLLATERALIZED_TOKEN),
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
        uint64 sbtStrikePriceE0 = sbtStrikePrice / (uint64(10)**DECIMALS_OF_ORACLE_PRICE);
        uint64 lbtStrikePriceE0 = lbtStrikePrice / (uint64(10)**DECIMALS_OF_ORACLE_PRICE);

        if (sbtStrikePrice != 0) {
            return BOND_TOKEN_NAMER.genBondTokenName("SBT", "SBT", maturity, sbtStrikePriceE0);
        } else if (lbtStrikePrice != 0) {
            return BOND_TOKEN_NAMER.genBondTokenName("LBT", "LBT", maturity, lbtStrikePriceE0);
        } else {
            return BOND_TOKEN_NAMER.genBondTokenName("IMT", "Immortal Option", maturity, 0);
        }
    }

    function _collateralAddress() internal view override returns (address) {
        return address(COLLATERALIZED_TOKEN);
    }

    function _getCollateralDecimals() internal view override returns (uint8) {
        return COLLATERALIZED_TOKEN.decimals();
    }

    function _sendCollateralTo(address receiver, uint256 amount) internal override {
        COLLATERALIZED_TOKEN.safeTransfer(receiver, amount);
    }

    function _receiveCollateralFrom(address sender, uint256 amount)
        internal
        virtual
        returns (uint256 receivedAmount)
    {
        uint256 beforeBalance = COLLATERALIZED_TOKEN.balanceOf(address(this));
        COLLATERALIZED_TOKEN.safeTransferFrom(sender, address(this), amount);
        uint256 afterBalance = COLLATERALIZED_TOKEN.balanceOf(address(this));
        receivedAmount = afterBalance.sub(beforeBalance);
    }
}
