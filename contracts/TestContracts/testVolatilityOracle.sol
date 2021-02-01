// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

contract testVolatilityOracle {
    uint64 Volatility = 10000000;

    function getVolatility(uint64) external view returns (uint64 volatilityE8) {
        return Volatility;
    }

    function changePriceAndVolatility(uint64 newVolatility) public {
        Volatility = newVolatility;
    }
}
