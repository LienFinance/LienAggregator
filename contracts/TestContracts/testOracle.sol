// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

contract testOracleForAggregator {
    uint256 Price = 40000000000;
    uint256 Volatility = 10000000;

    function latestPrice() external returns (uint256) {
        return Price;
    }

    function getVolatility() external returns (uint256) {
        return Volatility;
    }

    function changePriceAndVolatility(uint256 newPrice, uint256 newVolatility)
        public
    {
        Price = newPrice;
        Volatility = newVolatility;
    }

    function getData() public view returns (uint256, uint256) {
        return (Price, Volatility);
    }
}
