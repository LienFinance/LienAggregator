// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "../util/TransferETH.sol"; // this contract has payable function
import "./BondToken.sol";

contract BondTokenCollateralizedEth is BondToken, TransferETH {
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals
    ) BondToken(name, symbol, decimals) {}

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
