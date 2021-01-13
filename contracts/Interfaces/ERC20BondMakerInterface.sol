// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

interface ERC20BondMakerInterface {
    function issueNewBonds(uint256 bondGroupID, uint256 amount)
        external
        returns (uint256 issuedAmount);
}
