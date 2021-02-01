// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import {BondType} from "./Enums.sol";
import "../math/UseSafeMath.sol";
import "../math/AdvancedMath.sol";

/**
 * @dev The decimals of price, point, spotPrice and strikePrice are all the same.
 */
contract GeneralizedPricing is AdvancedMath {
    using SafeMath for uint256;

    /**
     * @dev sqrt(365*86400) * 10^8
     */
    int256 internal constant SQRT_YEAR_E8 = 5615.69229926 * 10**8;

    int256 internal constant MIN_ND1_E8 = 0.0001 * 10**8;
    int256 internal constant MAX_ND1_E8 = 0.9999 * 10**8;
    uint256 internal constant MAX_LEVERAGE_E8 = 1000 * 10**8;

    /**
     * @notice Calculate bond price and leverage by black-scholes formula.
     * @param bondType type of target bond.
     * @param points coodinates of polyline which is needed for price calculation
     * @param untilMaturity Remaining period of target bond in second
     **/
    function calcPriceAndLeverage(
        BondType bondType,
        uint256[] memory points,
        int256 spotPrice,
        int256 volatilityE8,
        int256 untilMaturity
    ) public pure returns (uint256 price, uint256 leverageE8) {
        if (bondType == BondType.LBT_SHAPE) {
            (price, leverageE8) = _calcLbtShapePriceAndLeverage(
                points,
                spotPrice,
                volatilityE8,
                untilMaturity
            );
        } else if (bondType == BondType.SBT_SHAPE) {
            (price, leverageE8) = _calcSbtShapePrice(
                points,
                spotPrice,
                volatilityE8,
                untilMaturity
            );
        } else if (bondType == BondType.TRIANGLE) {
            (price, leverageE8) = _calcTrianglePrice(
                points,
                spotPrice,
                volatilityE8,
                untilMaturity
            );
        } else if (bondType == BondType.PURE_SBT) {
            (price, leverageE8) = _calcPureSBTPrice(
                points,
                spotPrice,
                volatilityE8,
                untilMaturity
            );
        }
    }

    /**
     * @notice Calculate pure call option price and multiply incline of LBT.
     **/

    function _calcLbtShapePriceAndLeverage(
        uint256[] memory points,
        int256 spotPrice,
        int256 volatilityE8,
        int256 untilMaturity
    ) internal pure returns (uint256 price, uint256 leverageE8) {
        require(
            points.length == 3,
            "3 coordinates is needed for LBT price calculation"
        );
        uint256 inclineE8 =
            (points[2].mul(10**8)).div(points[1].sub(points[0]));
        (uint256 callOptionPriceE8, int256 nd1E8) =
            calcCallOptionPrice(
                spotPrice,
                int256(points[0]),
                volatilityE8,
                untilMaturity
            );
        price = (callOptionPriceE8 * inclineE8) / 10**8;
        leverageE8 = _calcLbtLeverage(
            uint256(spotPrice),
            price,
            (nd1E8 * int256(inclineE8)) / 10**8
        );
    }

    /**
     * @notice Calculate (etherPrice - call option price at strike price of SBT).
     **/
    function _calcPureSBTPrice(
        uint256[] memory points,
        int256 spotPrice,
        int256 volatilityE8,
        int256 untilMaturity
    ) internal pure returns (uint256 price, uint256 leverageE8) {
        require(
            points.length == 1,
            "1 coordinate is needed for pure SBT price calculation"
        );
        (uint256 callOptionPrice1, int256 nd1E8) =
            calcCallOptionPrice(
                spotPrice,
                int256(points[0]),
                volatilityE8,
                untilMaturity
            );
        price = uint256(spotPrice) > callOptionPrice1
            ? (uint256(spotPrice) - callOptionPrice1)
            : 0;
        leverageE8 = _calcLbtLeverage(uint256(spotPrice), price, 10**8 - nd1E8);
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
        uint256[] memory points,
        int256 spotPrice,
        int256 volatilityE8,
        int256 untilMaturity
    ) internal pure returns (uint256 price, uint256 leverageE8) {
        require(
            points.length == 3,
            "3 coordinates is needed for SBT price calculation"
        );
        uint256 inclineE8 =
            (points[2].mul(10**8)).div(points[1].sub(points[0]));
        (uint256 callOptionPrice1, int256 nd11E8) =
            calcCallOptionPrice(
                spotPrice,
                int256(points[0]),
                volatilityE8,
                untilMaturity
            );
        (uint256 callOptionPrice2, int256 nd12E8) =
            calcCallOptionPrice(
                spotPrice,
                int256(points[1]),
                volatilityE8,
                untilMaturity
            );
        price = callOptionPrice1 > callOptionPrice2
            ? (inclineE8 * (callOptionPrice1 - callOptionPrice2)) / 10**8
            : 0;
        leverageE8 = _calcLbtLeverage(
            uint256(spotPrice),
            price,
            (int256(inclineE8) * (nd11E8 - nd12E8)) / 10**8
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
        uint256[] memory points,
        int256 spotPrice,
        int256 volatilityE8,
        int256 untilMaturity
    ) internal pure returns (uint256 price, uint256 leverageE8) {
        require(
            points.length == 4,
            "4 coordinates is needed for triangle option price calculation"
        );
        uint256 incline1E8 =
            (points[2].mul(10**8)).div(points[1].sub(points[0]));
        uint256 incline2E8 =
            (points[2].mul(10**8)).div(points[3].sub(points[1]));
        (uint256 callOptionPrice1, int256 nd11E8) =
            calcCallOptionPrice(
                spotPrice,
                int256(points[0]),
                volatilityE8,
                untilMaturity
            );
        (uint256 callOptionPrice2, int256 nd12E8) =
            calcCallOptionPrice(
                spotPrice,
                int256(points[1]),
                volatilityE8,
                untilMaturity
            );
        (uint256 callOptionPrice3, int256 nd13E8) =
            calcCallOptionPrice(
                spotPrice,
                int256(points[3]),
                volatilityE8,
                untilMaturity
            );
        int256 nd1E8 =
            ((nd11E8 * int256(incline1E8)) +
                (nd13E8 * int256(incline2E8)) -
                (int256(incline1E8 + incline2E8) * nd12E8)) / 10**8;

        uint256 price12 =
            (callOptionPrice1 * incline1E8) + (callOptionPrice3 * incline2E8);
        price = price12 > (incline1E8 + incline2E8) * callOptionPrice2
            ? (price12 - ((incline1E8 + incline2E8) * callOptionPrice2)) / 10**8
            : 0;
        leverageE8 = _calcLbtLeverage(uint256(spotPrice), price, nd1E8);
    }

    /**
     * @dev calcCallOptionPrice() imposes the restrictions of strikePrice, spotPrice, nd1E8 and nd2E8.
     */
    function _calcLbtPrice(
        int256 spotPrice,
        int256 strikePrice,
        int256 nd1E8,
        int256 nd2E8
    ) internal pure returns (int256 lbtPrice) {
        int256 lowestPrice =
            (spotPrice > strikePrice) ? spotPrice - strikePrice : 0;
        lbtPrice = (spotPrice * nd1E8 - strikePrice * nd2E8) / 10**8;
        if (lbtPrice < lowestPrice) {
            lbtPrice = lowestPrice;
        }
    }

    /**
     * @dev calcCallOptionPrice() imposes the restrictions of spotPrice, lbtPrice and nd1E8.
     */
    function _calcLbtLeverage(
        uint256 spotPrice,
        uint256 lbtPrice,
        int256 nd1E8
    ) internal pure returns (uint256 lbtLeverageE8) {
        int256 modifiedNd1E8 =
            nd1E8 < MIN_ND1_E8 ? MIN_ND1_E8 : nd1E8 > MAX_ND1_E8
                ? MAX_ND1_E8
                : nd1E8;
        return
            lbtPrice != 0
                ? (uint256(modifiedNd1E8) * spotPrice) / lbtPrice
                : MAX_LEVERAGE_E8;
    }

    /**
     * @notice Calculate pure call option price and N(d1) by black-scholes formula.
     * @param spotPrice is a oracle price.
     * @param strikePrice Strike price of call option
     * @param volatilityE8 is a oracle volatility.
     * @param untilMaturity Remaining period of target bond in second
     **/
    function calcCallOptionPrice(
        int256 spotPrice,
        int256 strikePrice,
        int256 volatilityE8,
        int256 untilMaturity
    ) public pure returns (uint256 price, int256 nd1E8) {
        require(
            spotPrice > 0 && spotPrice < 10**13,
            "oracle price should be between 0 and 10^13"
        );
        require(
            volatilityE8 > 0 && volatilityE8 < 10 * 10**8,
            "oracle volatility should be between 0% and 1000%"
        );
        require(
            untilMaturity > 0 && untilMaturity < 31536000,
            "the bond should not have expired and less than 1 year"
        );
        require(
            strikePrice > 0 && strikePrice < 10**13,
            "strike price should be between 0 and 10^13"
        );

        int256 spotPerStrikeE4 = (spotPrice * 10**4) / strikePrice;
        int256 sigE8 =
            (volatilityE8 * (_sqrt(untilMaturity)) * (10**8)) / SQRT_YEAR_E8;

        int256 logSigE4 = _logTaylor(spotPerStrikeE4);
        int256 d1E4 = ((logSigE4 * 10**8) / sigE8) + (sigE8 / (2 * 10**4));
        nd1E8 = _calcPnorm(d1E4);

        int256 d2E4 = d1E4 - (sigE8 / 10**4);
        int256 nd2E8 = _calcPnorm(d2E4);
        price = uint256(_calcLbtPrice(spotPrice, strikePrice, nd1E8, nd2E8));
    }
}
