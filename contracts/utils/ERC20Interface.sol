// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;
import "../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ERC20Interface is IERC20 {
    function decimals() external view returns (uint8);

    function symbol() external view returns (string memory);
}
