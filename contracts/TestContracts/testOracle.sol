// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

contract testOracleForAggregator {
    uint256 Price = 40000000000;
    uint256 Volatility = 10000000;

    function latestPrice() external view returns (uint256) {
        return Price;
    }

    function getVolatility() external view returns (uint256) {
        return Volatility;
    }

    function getTimestamp(uint256 id) public view returns (uint256) {
        if (id == 2) {
            return block.timestamp;
        } else {
            return block.timestamp - 604800;
        }
    }

    function latestId() public pure returns (uint256) {
        return 2;
    }

    function getPrice(uint256) public view returns (uint256) {
        return Price;
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
