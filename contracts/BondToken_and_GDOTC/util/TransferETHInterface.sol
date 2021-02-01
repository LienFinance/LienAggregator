// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

interface TransferETHInterface {
    receive() external payable;

    event LogTransferETH(
        address indexed from,
        address indexed to,
        uint256 value
    );
}
