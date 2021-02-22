// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;
import "./StrategyForSimpleAggregatorETH.sol";

contract testSimpleStrategy is StrategyForSimpleAggregatorETH {
    constructor(
        ExchangeInterface _exchange,
        uint256 termInterval,
        uint256 termCF
    ) StrategyForSimpleAggregatorETH(_exchange, termInterval, termCF) {}

    function getLBTStrikePrice(
        BondMakerInterface _bondMaker,
        uint256 bondGroupID,
        bool reverseOracle
    ) public view returns (uint128 strikePrice, address LBTAddress) {
        (strikePrice, LBTAddress) = _getLBTStrikePrice(_bondMaker, bondGroupID, reverseOracle);
    }

    function getBaseAmount(SimpleAggregatorInterface aggregator) external view returns (uint256) {
        return _getBaseAmount(aggregator);
    }

    function applyDecimalGap(uint256 amount, int16 decimalGap) external pure returns (uint256) {
        return _applyDecimalGap(amount, decimalGap);
    }

    function getReversedValue(uint256 value, bool isReversedOracle)
        external
        pure
        returns (uint256)
    {
        return _getReversedValue(value, isReversedOracle);
    }

    function getMinBondAmount(
        BondMakerInterface bondMaker,
        uint256 bondGroupID,
        address aggregatorAddress
    ) external view returns (uint256 balance) {
        return _getMinBondAmount(bondMaker, bondGroupID, aggregatorAddress);
    }
}
