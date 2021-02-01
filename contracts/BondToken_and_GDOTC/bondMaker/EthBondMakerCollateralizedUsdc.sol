// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./BondMakerCollateralizedErc20.sol";

contract EthBondMakerCollateralizedUsdc is BondMakerCollateralizedErc20 {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    constructor(
        ERC20 usdcAddress,
        PriceOracleInterface ethPriceInverseOracleAddress,
        address feeTaker,
        BondTokenNameInterface bondTokenNameAddress,
        BondTokenFactory bondTokenFactoryAddress,
        uint256 maturityScale
    )
        BondMakerCollateralizedErc20(
            usdcAddress,
            ethPriceInverseOracleAddress,
            feeTaker,
            bondTokenNameAddress,
            bondTokenFactoryAddress,
            maturityScale,
            8,
            8
        )
    {}

    function _receiveCollateralFrom(address sender, uint256 amount)
        internal
        override
        returns (uint256 receivedAmount)
    {
        uint256 beforeBalance = COLLATERALIZED_TOKEN.balanceOf(address(this));
        COLLATERALIZED_TOKEN.safeTransferFrom(sender, address(this), amount);
        uint256 afterBalance = COLLATERALIZED_TOKEN.balanceOf(address(this));
        receivedAmount = afterBalance.sub(beforeBalance);
        require(
            receivedAmount == amount,
            "actual sent amount must be the same as the expected amount"
        );
    }

    function _getBondTokenName(uint256 maturity, bytes memory fnMap)
        internal
        view
        override
        returns (string memory symbol, string memory name)
    {
        bytes32 fnMapID = generateFnMapID(fnMap);
        LineSegment[] memory segments = _registeredFnMap[fnMapID];
        uint64 sbtStrikePrice = _getSbtStrikePrice(segments);
        uint64 lbtStrikePrice = _getLbtStrikePrice(segments);
        uint64 sbtStrikePriceInverseE0 =
            sbtStrikePrice != 0
                ? uint64(10)**DECIMALS_OF_ORACLE_PRICE / sbtStrikePrice
                : 0;
        uint64 lbtStrikePriceInverseE0 =
            lbtStrikePrice != 0
                ? uint64(10)**DECIMALS_OF_ORACLE_PRICE / lbtStrikePrice
                : 0;

        if (sbtStrikePrice != 0) {
            return
                BOND_TOKEN_NAMER.genBondTokenName(
                    "SBT",
                    "SBT",
                    maturity,
                    sbtStrikePriceInverseE0
                );
        } else if (lbtStrikePrice != 0) {
            return
                BOND_TOKEN_NAMER.genBondTokenName(
                    "LBT",
                    "LBT",
                    maturity,
                    lbtStrikePriceInverseE0
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
}
