// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;
import "./BondPricerWithAcceptableMaturity.sol";

contract testBondPricerWithAcceptableMaturity is BondPricerWithAcceptableMaturity {
    constructor(address originalBondPricerAddress)
        BondPricerWithAcceptableMaturity(originalBondPricerAddress)
    {}

    function isAcceptable(
        int256 etherPriceE8,
        int256 ethVolatilityE8,
        int256 untilMaturity
    ) public view {
        _isAcceptable(etherPriceE8, ethVolatilityE8, untilMaturity);
    }
}
