// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "../../../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestUSDC is ERC20 {
    constructor() ERC20("Test USDC", "USDC") {
        _setupDecimals(6);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}
