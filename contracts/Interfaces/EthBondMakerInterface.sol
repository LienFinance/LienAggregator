// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

interface EthBondMakerInterface {
    function issueNewBonds(uint256 bondGroupID)
        external
        payable
        returns (uint256 amount);
}
