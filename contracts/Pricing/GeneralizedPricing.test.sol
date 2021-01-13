// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;
import "./GeneralizedPricing.sol";

contract testGeneralizedPricing is GeneralizedPricing {
    function calcLbtShapePriceAndLeverage(
        uint64[] memory lines,
        int256 etherPriceE4,
        int256 ethVolatilityE8,
        int256 untilMaturity
    ) public pure returns (uint256 priceE8, uint256 leverageE4) {
        (priceE8, leverageE4) = _calcLbtShapePriceAndLeverage(
            lines,
            etherPriceE4,
            ethVolatilityE8,
            untilMaturity
        );
    }

    function calcPureSBTPrice(
        uint64[] memory lines,
        int256 etherPriceE4,
        int256 ethVolatilityE8,
        int256 untilMaturity
    ) public pure returns (uint256 priceE8, uint256 leverageE4) {
        (priceE8, leverageE4) = _calcPureSBTPrice(
            lines,
            etherPriceE4,
            ethVolatilityE8,
            untilMaturity
        );
    }

    function calcTrianglePrice(
        uint64[] memory lines,
        int256 etherPriceE4,
        int256 ethVolatilityE8,
        int256 untilMaturity
    ) public pure returns (uint256 priceE8, uint256 leverageE4) {
        (priceE8, leverageE4) = _calcTrianglePrice(
            lines,
            etherPriceE4,
            ethVolatilityE8,
            untilMaturity
        );
    }

    function calcSbtShapePrice(
        uint64[] memory lines,
        int256 etherPriceE4,
        int256 ethVolatilityE8,
        int256 untilMaturity
    ) public pure returns (uint256 priceE8, uint256 leverageE4) {
        (priceE8, leverageE4) = _calcSbtShapePrice(
            lines,
            etherPriceE4,
            ethVolatilityE8,
            untilMaturity
        );
    }
}
