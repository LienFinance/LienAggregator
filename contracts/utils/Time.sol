// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

abstract contract Time {
    function _getBlockTimestampSec()
        internal
        view
        returns (uint256 unixtimesec)
    {
        unixtimesec = block.timestamp; // solium-disable-line security/no-block-members
    }
}
