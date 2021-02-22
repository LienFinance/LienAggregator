// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;
import "./VolatilityOracleInterface.sol";
import "../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";
import "../../node_modules/@openzeppelin/contracts/utils/SafeCast.sol";

contract UseVolatilityOracle {
    using SafeMath for uint256;
    using SafeCast for uint256;
    VolatilityOracleInterface volOracle;

    constructor(VolatilityOracleInterface _volOracle) {
        volOracle = _volOracle;
    }

    function _getVolatility(uint256 maturity) internal view returns (uint256) {
        return volOracle.getVolatility(maturity.sub(block.timestamp).toUint64());
    }
}
