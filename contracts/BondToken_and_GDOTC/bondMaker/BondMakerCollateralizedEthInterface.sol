// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./BondMakerInterface.sol";

interface BondMakerCollateralizedEthInterface is BondMakerInterface {
    function issueNewBonds(uint256 bondGroupID) external payable returns (uint256 amount);
}
