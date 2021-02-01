// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "../util/Time.sol";
import "./OracleInterface.sol";

contract TestOracle is Time, OracleInterface {
    bool private _healthFlag = true;

    uint256 private immutable _createdAt;

    uint256[] private _timestamp;

    /// @dev 10^8 USD/ETH
    uint256[] private _rateETH2USD;

    /// @dev 10^8
    uint256[] private _volatility;

    constructor(uint256 rateETH2USD, uint256 volatility) {
        uint256 createdAt = _getBlockTimestampSec();
        _createdAt = createdAt;
        _rateETH2USD.push(0);
        _volatility.push(0);
        _timestamp.push(0);
        _rateETH2USD.push(rateETH2USD);
        _volatility.push(volatility);
        _timestamp.push(createdAt);
    }

    function testSetHealthFlag(bool healthFlag) public {
        _healthFlag = healthFlag;
    }

    function testSetOracleData(uint256 rateETH2USD, uint256 volatility) public {
        _rateETH2USD.push(rateETH2USD);
        _volatility.push(volatility);
        _timestamp.push(_getBlockTimestampSec());
    }

    function isWorking() external view override returns (bool) {
        return _healthFlag;
    }

    function latestId() public view override returns (uint256 id) {
        return _rateETH2USD.length - 1;
    }

    function latestPrice()
        external
        view
        override
        returns (uint256 rateETH2USD)
    {
        return getPrice(latestId());
    }

    function latestTimestamp()
        external
        view
        override
        returns (uint256 timestamp)
    {
        return getTimestamp(latestId());
    }

    function getPrice(uint256 id)
        public
        view
        override
        returns (uint256 rateETH2USD)
    {
        require(id <= latestId(), "given ID exceeds latest ID");
        return _rateETH2USD[id];
    }

    function getTimestamp(uint256 id)
        public
        view
        override
        returns (uint256 timestamp)
    {
        require(id <= latestId(), "given ID exceeds latest ID");
        return _timestamp[id];
    }

    function getVolatility()
        external
        view
        override
        returns (uint256 volatility)
    {
        return _volatility[latestId()];
    }

    function lastCalculatedVolatility()
        external
        view
        override
        returns (uint256 volatility)
    {
        return _volatility[_rateETH2USD.length - 1];
    }
}
