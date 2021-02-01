// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./Digits.sol";

contract TestDigits {
    using Digits for uint256;

    function testToDigitsString(uint256 value, uint256 digits)
        external
        pure
        returns (string memory)
    {
        return value.toString(digits);
    }
}
