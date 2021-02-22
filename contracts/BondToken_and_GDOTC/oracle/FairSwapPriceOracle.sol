// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "../../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";
import "../oracle/LatestPriceOracleInterface.sol";
import "../util/Time.sol";

interface BoxExchangeInterface {
    function getExchangeData()
        external
        view
        returns (
            uint256 boxNumber,
            uint256 _reserve0,
            uint256 _reserve1,
            uint256 totalShare,
            uint256 latestSpreadRate,
            uint256 token0PerShareE18,
            uint256 token1PerShareE18
        );
}

/**
 * @dev This oracle contract provides token price on FairSwap for users and DecentralizedOTC pool.
 * lowestPrice can be set by the deployer in order to prevent price manipulations on FairSwap.
 */
contract FairSwapPriceOracle is LatestPriceOracleInterface, Time {
    using SafeMath for uint256;

    BoxExchangeInterface public immutable fairSwap;
    address public immutable deployer;
    uint8 public immutable decimals;

    LatestPriceOracleInterface public baseTokenOracle;
    uint256 public lowestPrice;

    /**
     * @dev the deciamls of this oracle price is the same as that of base token oracle price.
     */
    constructor(
        address fairSwapAddress,
        address baseTokenOracleAddress,
        uint8 decimalsOfbaseTokenPrice
    ) {
        fairSwap = BoxExchangeInterface(fairSwapAddress);
        deployer = msg.sender;
        decimals = decimalsOfbaseTokenPrice;
        baseTokenOracle = LatestPriceOracleInterface(baseTokenOracleAddress);
    }

    function isWorking() public override returns (bool) {
        return address(baseTokenOracle) != address(0) && baseTokenOracle.isWorking();
    }

    function updateBaseTokenOracle(address baseTokenOracleAddress) external {
        require(
            msg.sender == deployer,
            "only deployer is allowed to change the oracle address of the base token"
        );
        baseTokenOracle = LatestPriceOracleInterface(baseTokenOracleAddress);
    }

    function deleteBaseTokenOracle() external {
        require(
            msg.sender == deployer,
            "only deployer is allowed to delete the oracle address of the base token"
        );
        delete baseTokenOracle;
    }

    function setLowestPrice(uint256 price) external {
        require(msg.sender == deployer, "only deployer is allowed to change lowest price");
        lowestPrice = price;
    }

    /**
     * @dev calculate the pool ratio at FairSwap.
     */
    function latestPrice() external override returns (uint256) {
        require(isWorking(), "the swap pair oracle is not working");

        (, uint256 baseTokenPoolAmount, uint256 quoteTokenPoolAmount, , , , ) = fairSwap
            .getExchangeData();

        uint256 baseTokenPrice = baseTokenOracle.latestPrice();

        // quoteTokenPrice = max(baseTokenPrice * baseTokenPoolAmount / quoteTokenPoolAmount, lowestPrice)
        uint256 quoteTokenPrice = baseTokenPrice.mul(baseTokenPoolAmount).div(quoteTokenPoolAmount);
        if (quoteTokenPrice < lowestPrice) {
            quoteTokenPrice = lowestPrice;
        }

        return quoteTokenPrice;
    }

    function latestTimestamp() external view override returns (uint256) {
        return _getBlockTimestampSec();
    }
}
