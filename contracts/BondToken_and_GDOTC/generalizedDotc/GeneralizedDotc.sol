// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./BondVsErc20Exchange.sol";
import "./BondVsEthExchange.sol";
import "./BondVsBondExchange.sol";

contract GeneralizedDotc is
    BondVsBondExchange,
    BondVsErc20Exchange,
    BondVsEthExchange
{
    constructor(
        BondMakerInterface bondMakerAddress,
        VolatilityOracleInterface volatilityOracleAddress,
        LatestPriceOracleInterface volumeCalculatorAddress,
        DetectBondShape bondShapeDetector
    )
        BondExchange(
            bondMakerAddress,
            volatilityOracleAddress,
            volumeCalculatorAddress,
            bondShapeDetector
        )
    {}
}
