// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./BondPricerInterface.sol";
import "./CustomGeneralizedPricing.sol";
import "../../../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../util/Time.sol";

contract BondPricer is CustomGeneralizedPricing, Time {
    using SafeMath for uint256;

    constructor(address originalBondPricerAddress)
        CustomGeneralizedPricing(originalBondPricerAddress)
    {}

    function _isAcceptableLbt(
        uint256[] memory,
        int256 etherPriceE8,
        int256 ethVolatilityE8,
        int256 untilMaturity,
        uint256,
        uint256
    ) internal pure override returns (bool) {
        return _isAcceptable(etherPriceE8, ethVolatilityE8, untilMaturity);
    }

    function _isAcceptableSbt(
        uint256[] memory,
        int256 etherPriceE8,
        int256 ethVolatilityE8,
        int256 untilMaturity,
        uint256,
        uint256
    ) internal pure override returns (bool) {
        return _isAcceptable(etherPriceE8, ethVolatilityE8, untilMaturity);
    }

    function _isAcceptableTriangleBond(
        uint256[] memory,
        int256 etherPriceE8,
        int256 ethVolatilityE8,
        int256 untilMaturity,
        uint256,
        uint256
    ) internal pure override returns (bool) {
        return _isAcceptable(etherPriceE8, ethVolatilityE8, untilMaturity);
    }

    function _isAcceptablePureSbt(
        uint256[] memory,
        int256 etherPriceE8,
        int256 ethVolatilityE8,
        int256 untilMaturity,
        uint256,
        uint256
    ) internal pure override returns (bool) {
        return _isAcceptable(etherPriceE8, ethVolatilityE8, untilMaturity);
    }

    function _isAcceptableOtherBond(
        uint256[] memory,
        int256,
        int256,
        int256,
        uint256,
        uint256
    ) internal pure override returns (bool) {
        return false;
    }

    function _isAcceptable(
        int256 etherPriceE8,
        int256 ethVolatilityE8,
        int256 untilMaturity
    ) internal pure returns (bool) {
        require(etherPriceE8 < 100000 * 10**8, "ETH price should be between $0 and $100000");
        require(ethVolatilityE8 < 10 * 10**8, "ETH volatility should be between 0% and 1000%");
        require(untilMaturity <= 12 weeks, "the bond maturity must be less than 12 weeks");
        return true;
    }
}
