// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

interface VolatilityOracleInterface {
    function getVolatility(uint64 untilMaturity) external view returns (uint64 volatilityE8);
}
