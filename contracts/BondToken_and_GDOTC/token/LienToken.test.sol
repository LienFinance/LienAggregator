// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./ERC20Vestable.sol";

/**
 * @notice THIS FILE IS JUST A COPY FOR TEST. NOT TO BE USED IN MAINNET AND NOT FOR AUDIT.
 */

contract TestLienToken is ERC20Vestable {
    constructor() ERC20("testLienToken", "testLien") {
        _setupDecimals(8);
    }

    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }

    receive() external payable {}

    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}
