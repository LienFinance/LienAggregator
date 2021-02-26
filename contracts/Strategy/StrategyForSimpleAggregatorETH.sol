// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;
import "./StrategyForSimpleAggregator.sol";

contract StrategyForSimpleAggregatorETH is StrategyForSimpleAggregator {
    using SafeMath for uint256;
    ExchangeInterface internal immutable exchange;

    constructor(
        ExchangeInterface _exchange,
        uint256 termInterval,
        uint256 termCF
    ) StrategyForSimpleAggregator(termInterval, termCF) {
        exchange = _exchange;
        require(address(_exchange) != address(0), "_exchange cannot be zero");
    }

    /**
     * @notice Determine the bond token amount to be issued/burned.
     * @param issueBondGroupId Bond group ID to be issued
     * @param bondGroupList Determine bond group ID to be burned from this list.
     * @param ethAmount ETH amount to be depositted to GDOTC (if aggregator is ETH aggregator)
     */
    function getTrancheBonds(
        BondMakerInterface bondMaker,
        address aggregatorAddress,
        uint256 issueBondGroupId,
        uint256 price,
        uint256[] calldata bondGroupList,
        uint64 priceUnit,
        bool isReversedOracle
    )
        public
        view
        override
        returns (
            uint256 issueAmount,
            uint256 ethAmount,
            uint256[2] memory IDAndAmountOfBurn
        )
    {
        if (SimpleAggregatorInterface(aggregatorAddress).getCollateralAddress() == address(0)) {
            uint256 currentDepositAmount = exchange.ethAllowance(aggregatorAddress);
            uint256 baseETHAmount = aggregatorAddress.balance.div(10);
            if (currentDepositAmount < baseETHAmount) {
                ethAmount = baseETHAmount.sub(currentDepositAmount);
            }
        }

        (issueAmount, , IDAndAmountOfBurn) = super.getTrancheBonds(
            bondMaker,
            aggregatorAddress,
            issueBondGroupId,
            price,
            bondGroupList,
            priceUnit,
            isReversedOracle
        );
    }
}
