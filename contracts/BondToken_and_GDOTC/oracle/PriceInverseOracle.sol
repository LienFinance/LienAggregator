// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./OracleInterface.sol";
import "../math/UseSafeMath.sol";

contract PriceInverseOracle is OracleInterface {
    using SafeMath for uint256;

    OracleInterface internal immutable BASE_ORACLE;

    constructor(address baseOracleAddress) {
        BASE_ORACLE = OracleInterface(baseOracleAddress);
    }

    function isWorking() external override returns (bool) {
        return BASE_ORACLE.isWorking();
    }

    function latestId() public override returns (uint256 id) {
        return BASE_ORACLE.latestId();
    }

    function latestPrice() external override returns (uint256 rateETH2USD) {
        return _calcPrice(BASE_ORACLE.latestPrice());
    }

    function latestTimestamp() external override returns (uint256 timestamp) {
        return BASE_ORACLE.latestTimestamp();
    }

    function getPrice(uint256 id)
        public
        override
        returns (uint256 rateETH2USD)
    {
        return _calcPrice(BASE_ORACLE.getPrice(id));
    }

    function getTimestamp(uint256 id)
        public
        override
        returns (uint256 timestamp)
    {
        return BASE_ORACLE.getTimestamp(id);
    }

    function getVolatility() external override returns (uint256 volatility) {
        return _calcVolatility(BASE_ORACLE.getVolatility());
    }

    function lastCalculatedVolatility()
        external
        view
        override
        returns (uint256 volatility)
    {
        return _calcVolatility(BASE_ORACLE.lastCalculatedVolatility());
    }

    function getBaseOracleAddress() external view returns (address) {
        return address(BASE_ORACLE);
    }

    function _calcPrice(uint256 basePriceE8) internal pure returns (uint256) {
        return _calcInverse(basePriceE8);
    }

    function _calcVolatility(uint256 baseVolatilityE8)
        internal
        pure
        returns (uint256)
    {
        return baseVolatilityE8;
    }

    function _calcInverse(uint256 valueE8) internal pure returns (uint256) {
        return uint256(10**16).div(valueE8);
    }
}
