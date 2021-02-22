// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./PriceInverseOracle.sol";
import "./oracle.test.sol";

contract TestPriceInverseOracle is PriceInverseOracle {
    using SafeMath for uint256;

    constructor(address baseOracleAddress) PriceInverseOracle(baseOracleAddress) {
        // Ensure baseOracleAddress has testSetOracleData method.
        TestOracle(baseOracleAddress);
    }

    function testSetOracleData(uint256 price, uint256 volatility) public {
        TestOracle(address(BASE_ORACLE)).testSetOracleData(_calcInverse(price), volatility);
    }

    function testSetBaseOracleData(uint256 price, uint256 volatility) public {
        TestOracle(address(BASE_ORACLE)).testSetOracleData(price, volatility);
    }
}
