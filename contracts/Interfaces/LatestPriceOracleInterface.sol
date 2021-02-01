// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

/**
 * @dev Interface of the price oracle.
 */
interface LatestPriceOracleInterface {
    /**
     * @dev Returns `true`if oracle is working.
     */
    function isWorking() external returns (bool);

    /**
     * @dev Returns the last updated price. Decimals is 8.
     */
    function latestPrice() external returns (uint256);

    /**
     * @dev Returns the timestamp of the last updated price.
     */
    function latestTimestamp() external returns (uint256);
}
