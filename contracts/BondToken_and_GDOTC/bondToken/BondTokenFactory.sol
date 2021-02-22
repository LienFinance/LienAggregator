// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./BondTokenCollateralizedErc20.sol";
import "./BondTokenCollateralizedEth.sol";

contract BondTokenFactory {
    address private constant ETH = address(0);

    function createBondToken(
        address collateralizedTokenAddress,
        string calldata name,
        string calldata symbol,
        uint8 decimals
    ) external returns (address createdBondAddress) {
        if (collateralizedTokenAddress == ETH) {
            BondTokenCollateralizedEth bond = new BondTokenCollateralizedEth(
                name,
                symbol,
                decimals
            );
            bond.transferOwnership(msg.sender);
            return address(bond);
        } else {
            BondTokenCollateralizedErc20 bond = new BondTokenCollateralizedErc20(
                ERC20(collateralizedTokenAddress),
                name,
                symbol,
                decimals
            );
            bond.transferOwnership(msg.sender);
            return address(bond);
        }
    }
}
