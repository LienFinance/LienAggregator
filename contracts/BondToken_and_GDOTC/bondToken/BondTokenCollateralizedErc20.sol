// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./BondToken.sol";
import "../../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract BondTokenCollateralizedErc20 is BondToken {
    using SafeERC20 for ERC20;

    ERC20 internal immutable COLLATERALIZED_TOKEN;

    constructor(
        ERC20 collateralizedTokenAddress,
        string memory name,
        string memory symbol,
        uint8 decimals
    ) BondToken(name, symbol, decimals) {
        COLLATERALIZED_TOKEN = collateralizedTokenAddress;
    }

    function _getCollateralDecimals() internal view override returns (uint8) {
        return COLLATERALIZED_TOKEN.decimals();
    }

    function _sendCollateralTo(address receiver, uint256 amount)
        internal
        override
    {
        COLLATERALIZED_TOKEN.safeTransfer(receiver, amount);
    }
}
