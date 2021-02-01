// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "../oracle/FixedPriceOracle.sol";

contract USDCOracle is FixedPriceOracle(1 * 10**8) {}
