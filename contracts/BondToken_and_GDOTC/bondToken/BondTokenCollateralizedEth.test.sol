// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./BondTokenCollateralizedEth.sol";

contract TestBondTokenCollateralizedEth is BondTokenCollateralizedEth {
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals
    ) BondTokenCollateralizedEth(name, symbol, decimals) {}

    function getDeployer() external view returns (address) {
        return owner();
    }
}
