// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import {BondType} from "../utils/Enums.sol";
import "../utils/AdvancedMath.sol";
import "../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";

contract GeneralizedPricing is AdvancedMath {
    using SafeMath for uint256;

    using SafeMath for uint64;
    /**
     * @dev sqrt(365*86400) * 10^8
     */
    int256 internal constant SQRT_YEAR_E8 = 561569229926;

    uint256 internal constant MIN_EXCHANG_RATE_E8 = 0.000001 * 10**8;
    uint256 internal constant MAX_EXCHANG_RATE_E8 = 1000000 * 10**8;

    int256 internal constant MIN_ND1 = 1;
    int256 internal constant MAX_ND1 = 9999;

    int256 internal constant MAX_SPREAD_E7 = 0.15 * 10**7; // 15%

    /**
     * @notice Calculate bond price and leverage by black-scholes formula.
     * @param bondType type of target bond.
     * @param points coodinates of polyline which is needed for price calculation
     * @param untilMaturity Remaining period of target bond in second
     **/
    function calcPriceAndLeverage(
        BondType bondType,
        uint64[] memory points,
        int256 etherPriceE4,
        int256 ethVolatilityE8,
        int256 untilMaturity
    ) public pure returns (uint256 priceE8, uint256 leverageE4) {
        if (bondType == BondType.LBT_SHAPE) {
            (priceE8, leverageE4) = _calcLbtShapePriceAndLeverage(
                points,
                etherPriceE4,
                ethVolatilityE8,
                untilMaturity
            );
        } else if (bondType == BondType.SBT_SHAPE) {
            (priceE8, leverageE4) = _calcSbtShapePrice(
                points,
                etherPriceE4,
                ethVolatilityE8,
                untilMaturity
            );
        } else if (bondType == BondType.TRIANGLE) {
            (priceE8, leverageE4) = _calcTrianglePrice(
                points,
                etherPriceE4,
                ethVolatilityE8,
                untilMaturity
            );
        } else if (bondType == BondType.PURE_SBT) {
            (priceE8, leverageE4) = _calcPureSBTPrice(
                points,
                etherPriceE4,
                ethVolatilityE8,
                untilMaturity
            );
        }
    }

    /**
     * @notice Calculate pure call option price and multiply incline of LBT.
     **/

    function _calcLbtShapePriceAndLeverage(
        uint64[] memory points,
        int256 etherPriceE4,
        int256 ethVolatilityE8,
        int256 untilMaturity
    ) internal pure returns (uint256 priceE8, uint256 leverageE4) {
        require(
            points.length == 3,
            "Three Coordinates is needed for LBT price calculation"
        );
        uint256 inclineE8 = (points[2].mul(10**8)).div(
            points[1].sub(points[0])
        );
        (uint256 callOptionPriceE4, int256 nd1E4) = calcCallOptionPrice(
            etherPriceE4,
            int256(points[0]),
            ethVolatilityE8,
            untilMaturity
        );
        priceE8 = (callOptionPriceE4 * inclineE8) / 10**4;
        leverageE4 = _calcLbtLeverage(
            uint256(etherPriceE4),
            priceE8.div(10**4),
            (nd1E4 * int256(inclineE8)) / 10**8
        );
    }

    /**
     * @notice Calculate (etherPrice - call option price at strike price of SBT).
     **/
    function _calcPureSBTPrice(
        uint64[] memory points,
        int256 etherPriceE4,
        int256 ethVolatilityE8,
        int256 untilMaturity
    ) internal pure returns (uint256 priceE8, uint256 leverageE4) {
        require(
            points.length == 1,
            "Only One Coordinate is needed for Pure SBT price calculation"
        );
        (uint256 callOptionPrice1E4, int256 nd1E4) = calcCallOptionPrice(
            etherPriceE4,
            int256(points[0]),
            ethVolatilityE8,
            untilMaturity
        );
        priceE8 = uint256(etherPriceE4) > callOptionPrice1E4
            ? (uint256(etherPriceE4) - callOptionPrice1E4) * 10**4
            : 0;
        leverageE4 = _calcLbtLeverage(
            uint256(etherPriceE4),
            priceE8.div(10**4),
            10000 - nd1E4
        );
    }

    /**
     * @notice Calculate (call option1  - call option2) * incline of SBT.

              ______                 /                            
             /                      /                            
            /          =           /        -                   /
    _______/               _______/                 ___________/   
    SBT SHAPE BOND         CALL OPTION 1            CALL OPTION 2
     **/
    function _calcSbtShapePrice(
        uint64[] memory points,
        int256 etherPriceE4,
        int256 ethVolatilityE8,
        int256 untilMaturity
    ) internal pure returns (uint256 priceE8, uint256 leverageE4) {
        require(
            points.length == 3,
            "Two Coordinates is needed for SBT price calculation"
        );
        uint256 inclineE8 = (points[2].mul(10**8)).div(
            points[1].sub(points[0])
        );
        (uint256 callOptionPrice1E4, int256 nd11E4) = calcCallOptionPrice(
            etherPriceE4,
            int256(points[0]),
            ethVolatilityE8,
            untilMaturity
        );
        (uint256 callOptionPrice2E4, int256 nd12E4) = calcCallOptionPrice(
            etherPriceE4,
            int256(points[1]),
            ethVolatilityE8,
            untilMaturity
        );
        priceE8 = callOptionPrice1E4 > callOptionPrice2E4
            ? (inclineE8 * (callOptionPrice1E4 - callOptionPrice2E4)) / 10**4
            : 0;
        leverageE4 = _calcLbtLeverage(
            uint256(etherPriceE4),
            priceE8 / 10**4,
            (int256(inclineE8) * (nd11E4 - nd12E4)) / 10**8
        );
    }

    /**
      * @notice Calculate (call option1 * left incline) - (call option2 * (left incline + right incline)) + (call option3 * right incline).

                                                                   /
                                                                  /
                                                                 /
              /\                            /                    \
             /  \                          /                      \
            /    \            =           /     -                  \          +          
    _______/      \________       _______/               _______    \             __________________
                                                                     \                          \
                                                                      \                          \

    **/
    function _calcTrianglePrice(
        uint64[] memory points,
        int256 etherPriceE4,
        int256 ethVolatilityE8,
        int256 untilMaturity
    ) internal pure returns (uint256 priceE8, uint256 leverageE4) {
        require(
            points.length == 4,
            "Four Coordinates is needed for Triangle option price calculation"
        );
        uint256 incline1E8 = (points[2].mul(10**8)).div(
            points[1].sub(points[0])
        );
        uint256 incline2E8 = (points[2].mul(10**8)).div(
            points[3].sub(points[1])
        );
        (uint256 callOptionPrice1E4, int256 nd11E4) = calcCallOptionPrice(
            etherPriceE4,
            int256(points[0]),
            ethVolatilityE8,
            untilMaturity
        );
        (uint256 callOptionPrice2E4, int256 nd12E4) = calcCallOptionPrice(
            etherPriceE4,
            int256(points[1]),
            ethVolatilityE8,
            untilMaturity
        );
        (uint256 callOptionPrice3E4, int256 nd13E4) = calcCallOptionPrice(
            etherPriceE4,
            int256(points[3]),
            ethVolatilityE8,
            untilMaturity
        );
        int256 nd1E4 = ((nd11E4 * int256(incline1E8)) +
            (nd13E4 * int256(incline2E8)) -
            (int256(incline1E8 + incline2E8) * nd12E4)) / (10**8);
        leverageE4 = _calcLbtLeverage(
            uint256(etherPriceE4),
            priceE8.div(10**4),
            nd1E4
        );

        uint256 price12E12 = (callOptionPrice1E4 * incline1E8) +
            (callOptionPrice3E4 * incline2E8);
        priceE8 = price12E12 > (incline1E8 + incline2E8) * callOptionPrice2E4
            ? (price12E12 - ((incline1E8 + incline2E8) * callOptionPrice2E4)) /
                10**4
            : 0;
    }

    function _calcLbtPrice(
        int256 etherPriceE4,
        int256 strikePriceE4,
        int256 nd1E4,
        int256 nd2E4
    ) public pure returns (int256 lbtPriceE4) {
        int256 lowestPriceE4 = (etherPriceE4 > strikePriceE4)
            ? etherPriceE4 - strikePriceE4
            : 0;
        lbtPriceE4 =
            (etherPriceE4 * (nd1E4) - (strikePriceE4 * nd2E4)) /
            (10**4);
        if (lbtPriceE4 < lowestPriceE4) {
            lbtPriceE4 = lowestPriceE4;
        }
    }

    function _calcLbtLeverage(
        uint256 etherPriceE4,
        uint256 lbtPriceE4,
        int256 nd1E4
    ) public pure returns (uint256 lbtLeverageE4) {
        int256 modifiedNd1E4 = nd1E4 < MIN_ND1 ? MIN_ND1 : nd1E4 > MAX_ND1
            ? MAX_ND1
            : nd1E4;
        return
            lbtPriceE4 != 0
                ? ((uint256(modifiedNd1E4) * etherPriceE4) / lbtPriceE4)
                : 100 * 10**4;
    }

    function calcCallOptionPrice(
        int256 etherPriceE4,
        int256 strikePriceE4,
        int256 ethVolatilityE8,
        int256 untilMaturity
    ) public pure returns (uint256 priceE4, int256 nd1E4) {
        require(
            etherPriceE4 > 0 && etherPriceE4 < 10**15,
            "ETH price should be between $0 and $10000000"
        );
        require(
            ethVolatilityE8 > 0 && ethVolatilityE8 < 10**15,
            "ETH volatility should be between 0% and 1000%"
        );
        require(
            untilMaturity > 0 || untilMaturity < 31536000,
            "LBT should not have expired and less than 1 year"
        );
        require(
            strikePriceE4 > 0 && strikePriceE4 < 10**15,
            "Strikeprice should be between $0 and $10000000"
        );
        {
            /* int256 lowestPriceE4 = (etherPriceE4 > strikePriceE4)
                ? etherPriceE4 - strikePriceE4
                : 0;*/
            int256 spotPerStrikeE4 = (etherPriceE4 * (10**4)) / strikePriceE4;
            int256 sigE8 = (ethVolatilityE8 *
                (_sqrt(untilMaturity)) *
                (10**8)) / (SQRT_YEAR_E8);

            // int256 lbtPriceE4;

            // if (spotPerStrikeE4 < 30 * 10**3) {
            int256 logSigE4 = _logTaylor(spotPerStrikeE4);
            int256 d1E4 = ((logSigE4 * 10**8) / sigE8) + (sigE8 / (2 * 10**4));
            nd1E4 = _calcPnorm(d1E4);

            // if (spotPerStrikeE4 > 0.4 * 10**4) {
            int256 d2E4 = d1E4 - (sigE8 / 10**4);
            /*if (
                        d1E4 > -3 * 10**4 &&
                        d1E4 < 3 * 10**4 &&
                        d2E4 > -3 * 10**4 &&
                        d2E4 < 3 * 10**4
                    ) {*/
            int256 nd2E4 = _calcPnorm(d2E4);
            int256 lbtPriceE4 = _calcLbtPrice(
                etherPriceE4,
                strikePriceE4,
                nd1E4,
                nd2E4
            );
            // }
            // }
            // }
            priceE4 = uint256(lbtPriceE4);
        }
    }
}
