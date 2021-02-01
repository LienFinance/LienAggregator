// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./BondMakerInterface.sol";

interface BondMakerCollateralizedErc20Interface is BondMakerInterface {
    function issueNewBonds(uint256 bondGroupID, uint256 amount)
        external
        returns (uint256 bondAmount);
}
