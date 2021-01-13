// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

abstract contract AdvancedMath {
    /**
     * @dev sqrt(2*PI) * 10^8
     */
    int256 internal constant SQRT_2PI_E8 = 250662827;
    int256 internal constant PI_E8 = 314159265;
    int256 internal constant E_E8 = 271828182;
    int256 internal constant LOG2_E8 = 30102999;
    int256 internal constant LOG3_E8 = 47712125;

    int256 internal constant p = 23164190;
    int256 internal constant b1 = 31938153;
    int256 internal constant b2 = -35656378;
    int256 internal constant b3 = 178147793;
    int256 internal constant b4 = -182125597;
    int256 internal constant b5 = 133027442;

    /**
     * @dev Calcurate an approximate value of the square root of x by Newton's method.
     */
    function _sqrt(int256 x) internal pure returns (int256 y) {
        require(
            x >= 0,
            "cannot calculate the square root of a negative number"
        );
        int256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    /**s
     * @notice Calculate an approximate value of the logarithm of input value by
     * Taylor expansion.
     * @dev log(x + 1) = x - 1/2 x^2 + 1/3 x^3 - 1/4 x^4 + 1/5 x^5
     *                     - 1/6 x^6 + 1/7 x^7 - 1/8 x^8 + ...
     */
    function _logTaylor(int256 inputE4)
        internal
        pure
        returns (int256 outputE4)
    {
        int256 inputE8 = inputE4 * 10**4;
        while (inputE8 > 10**8) {
            outputE4 += 10**4;
            inputE8 = (inputE8 * 10**8) / E_E8;
        }
        outputE4 += _logTaylor1(inputE8 / 10**4 - 10**4);
        outputE4 = outputE4;
    }

    /*
    function _logTaylor(int256 inputE4)
        internal
        pure
        returns (int256 outputE4)
    {
        if (inputE4 < 10000) {
            return _logTaylor1(inputE4);
        } else if (inputE4 < 20000) {
            return _logTaylor2(inputE4);
        } else {
            return _logTaylor3(inputE4);
        }
    }*/
    /*
    function _logTaylor1(int256 inputE4)
        internal
        pure
        returns (int256 outputE4)
    {
        outputE4 = 0;
        int256 sign;
        require(inputE4 < 2 * 10**4, "inputE4 < 20000 (2) is required");
        for (uint256 i = 1; i < 9; i++) {
            if (i % 2 == 0) {
                sign = -1;
            } else {
                sign = 1;
            }
            outputE4 = outputE4.add(
                _pow(inputE4, i).div(_pow(10, 4 * i - 4)).div(int256(i)).mul(
                    sign
                )
            );
        }
    }
*/

    function _logTaylor1(int256 inputE4)
        internal
        pure
        returns (int256 outputE4)
    {
        outputE4 =
            inputE4 -
            inputE4**2 /
            (2 * 10**4) +
            inputE4**3 /
            (3 * 10**8) -
            inputE4**4 /
            (4 * 10**12) +
            inputE4**5 /
            (5 * 10**16) -
            inputE4**6 /
            (6 * 10**20) +
            inputE4**7 /
            (7 * 10**24) -
            inputE4**8 /
            (8 * 10**28);
    }

    function _calcPnorm(int256 inputE4)
        internal
        pure
        returns (int256 outputE4)
    {
        require(inputE4 < 44 * 10**5, "Input is too large");
        int256 _inputE4 = inputE4 > 0 ? inputE4 : inputE4 * (-1);
        int256 t = 10**16 / (10**8 + (p * _inputE4) / 10**4);
        int256 X2 = (inputE4 * inputE4) / 2;
        int256 exp2X2 = 10**8 +
            X2 +
            (X2**2 / (2 * 10**8)) +
            (X2**3 / (6 * 10**16)) +
            (X2**4 / (24 * 10**24)) +
            (X2**5 / (120 * 10**32)) +
            (X2**6 / (720 * 10**40));
        int256 Z = (10**24 / exp2X2) / SQRT_2PI_E8;
        int256 y = (b5 * t) / 10**8;
        y = ((y + b4) * t) / 10**8;
        y = ((y + b3) * t) / 10**8;
        y = ((y + b2) * t) / 10**8;
        y = 10**8 - (Z * ((y + b1) * t)) / 10**16;
        return inputE4 > 0 ? y / 10**4 : 10000 - y / 10**4;
    }
}
