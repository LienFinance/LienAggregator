// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./LatestPriceOracleInterface.sol";

/**
 * @dev Interface of the price oracle.
 */
interface PriceOracleInterface is LatestPriceOracleInterface {
    /**
     * @dev Returns the latest id. The id start from 1 and increments by 1.
     */
    function latestId() external returns (uint256);

    /**
     * @dev Returns the historical price specified by `id`. Decimals is 8.
     */
    function getPrice(uint256 id) external returns (uint256);

    /**
     * @dev Returns the timestamp of historical price specified by `id`.
     */
    function getTimestamp(uint256 id) external returns (uint256);
}
