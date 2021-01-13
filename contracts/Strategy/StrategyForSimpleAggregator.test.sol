// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;
import "./StrategyForSimpleAggregator.sol";

contract testSimpleStrategy is StrategyForSimpleAggregator {
    constructor(
        ExchangeInterface _exchange,
        uint256 termInterval,
        uint256 termCF
    ) StrategyForSimpleAggregator(_exchange, termInterval, termCF) {}

    function getLBTStrikePrice(
        BondMakerInterface _bondMaker,
        uint256 bondGroupID
    ) public view returns (uint256 strikePrice, address LBTAddress) {
        (strikePrice, LBTAddress) = _getLBTStrikePrice(_bondMaker, bondGroupID);
    }

    function getBaseAmount(SimpleAggregatorInterface aggregator)
        external
        view
        returns (uint256)
    {
        return _getBaseAmount(aggregator);
    }

    function applyDecimalGap(uint256 amount, int16 decimalGap)
        external
        pure
        returns (uint256)
    {
        return _applyDecimalGap(amount, decimalGap);
    }
}
