// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./FairSwapPriceOracle.sol";

/**
 * @dev This oracle contract provides LIEN/USD price on FairSwap for users and DecentralizedOTC contracts.
 * The deployer of this contract can set a lowest price in order to prevent price manipulations on FairSwap.
 */
contract LienPriceOracle is FairSwapPriceOracle {
    /**
     * @dev the deciamls of this oracle price is 8.
     * @param fairSwapAddress is the target FairSwap address.
     * @param swapPairOracleAddress is the oracle of the swap pair token price in dollars.
     */
    constructor(address fairSwapAddress, address swapPairOracleAddress)
        FairSwapPriceOracle(fairSwapAddress, swapPairOracleAddress, 8)
    {}
}
