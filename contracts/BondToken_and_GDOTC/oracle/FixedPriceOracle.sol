// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./PriceOracleInterface.sol";
import "../util/Time.sol";

contract FixedPriceOracle is PriceOracleInterface, Time {
    uint256 private immutable _price;

    constructor(uint256 fixedPrice) {
        _price = fixedPrice;
    }

    function isWorking() external pure override returns (bool) {
        return true;
    }

    function latestId() public view override returns (uint256) {
        return _getBlockTimestampSec();
    }

    /**
     * @notice Returns timestamp of latest price.
     */
    function latestTimestamp() public view override returns (uint256) {
        return getTimestamp(latestId());
    }

    /**
     * @notice This function returns current USD/USDC rate.
     */
    function latestPrice() public view override returns (uint256) {
        return getPrice(latestId());
    }

    function getTimestamp(uint256 id) public pure override returns (uint256) {
        return id;
    }

    function getPrice(uint256) public view override returns (uint256) {
        return _price;
    }
}
