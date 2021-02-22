// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./OracleInterface.sol";
import "./VolatilityOracleInterface.sol";
import "../../../node_modules/@openzeppelin/contracts/utils/SafeCast.sol";

contract HistoricalVolatilityOracle is VolatilityOracleInterface {
    using SafeCast for uint256;

    OracleInterface internal immutable _priceOracleContract;

    constructor(OracleInterface oracleAddress) {
        _priceOracleContract = oracleAddress;
    }

    /**
     * @dev Returns the same value regardless of the duration until maturity.
     */
    function getVolatility(uint64) external view override returns (uint64 volatilityE8) {
        return _priceOracleContract.lastCalculatedVolatility().toUint64();
    }
}
