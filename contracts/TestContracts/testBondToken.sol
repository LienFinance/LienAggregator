// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "../../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../BondToken_and_GDOTC/util/TransferETH.sol";

contract testBondToken is ERC20, TransferETH {
    constructor() ERC20("TESTTOKEN", "test") {}

    function mint(address account, uint256 amount) public payable returns (bool success) {
        _mint(account, amount);
        return true;
    }

    function burnAll() external returns (uint256) {
        _burn(msg.sender, balanceOf(msg.sender));
        _transferETH(msg.sender, address(this).balance);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }

    function changeDecimal(uint8 decimals) public {
        _setupDecimals(decimals);
    }
}

contract testErc20BondToken is ERC20 {
    IERC20 collateral;

    constructor(address _collateralAddress) ERC20("TESTTOKEN", "test") {
        collateral = IERC20(_collateralAddress);
    }

    function mint(address account, uint256 amount) public payable returns (bool success) {
        _mint(account, amount);
        return true;
    }

    function burnAll() external returns (uint256) {
        _burn(msg.sender, balanceOf(msg.sender));
        collateral.transfer(msg.sender, collateral.balanceOf(address(this)));
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }

    function changeDecimal(uint8 decimals) public {
        _setupDecimals(decimals);
    }
}
