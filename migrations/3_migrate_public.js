const BondMaker = artifacts.require('TestBondMaker');
const Aggregator = artifacts.require('SimpleAggregatorCollateralizedEth');
const Strategy = artifacts.require('StrategyForSimpleAggregatorETH');
const Exchange = artifacts.require('TestExchange');
const VolOracle = artifacts.require('testVolatilityOracle');
const Oracle = artifacts.require('testOracleForAggregator');
const GeneralizedPricing = artifacts.require('GeneralizedPricing');
const Pricer = artifacts.require('BondPricerWithAcceptableMaturity');
const fs = require('fs');

module.exports = async (deployer, network) => {
    if (network === 'ropsten' || network === 'mainnet' || network === 'local') {
        const inputFile = process.env.DUMP || 'dump.json';
        const data = JSON.parse(fs.readFileSync(inputFile, 'utf8'));

        await deployer.deploy(GeneralizedPricing);
        const generalizedPricingInstance = await GeneralizedPricing.deployed();
        await deployer.deploy(Pricer, generalizedPricingInstance.address);
        const pricerInstance = await Pricer.deployed();
        await deployer.deploy(Strategy, data.Exchange, 604800, 144000);
        const strategyInstance = await Strategy.deployed();
        await deployer.deploy(
            Aggregator,
            data.TestOracle,
            pricerInstance.address,
            strategyInstance.address,
            data.Exchange,
            data.TestVolOracle,
            100000
        );
        if ((await pricerInstance.owner()) !== aggregatorInstance.address) {
            await pricerInstance.transferOwnership(aggregatorInstance.address);
        }
    }
};
