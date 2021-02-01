const BondMaker = artifacts.require('TestBondMaker');
const Aggregator = artifacts.require('testSimpleAggregatorCollateralizedEth');
const Strategy = artifacts.require('StrategyForSimpleAggregatorETH');
const Exchange = artifacts.require('TestExchange');
const VolOracle = artifacts.require('testVolatilityOracle');
const Oracle = artifacts.require('testOracleForAggregator');
const GeneralizedPricing = artifacts.require('GeneralizedPricing');
const Pricer = artifacts.require('BondPricerWithAcceptableMaturity');
const ERC20 = artifacts.require('ERC20');

module.exports = async (deployer, network) => {
    if (network != 'ropsten' && network != 'mainnet') {
        await deployer.deploy(Oracle);
        const oracleInstance = await Oracle.deployed();
        await deployer.deploy(GeneralizedPricing);
        const generalizedPricingInstance = await GeneralizedPricing.deployed();
        await deployer.deploy(Pricer, generalizedPricingInstance.address);
        const pricerInstance = await Pricer.deployed();
        await deployer.deploy(VolOracle);
        const volOracleInstance = await VolOracle.deployed();
        await deployer.deploy(BondMaker);
        const bondMakerInstance = await BondMaker.deployed();
        await deployer.deploy(Exchange, bondMakerInstance.address);
        const exchangeInstance = await Exchange.deployed();
        await deployer.deploy(Strategy, exchangeInstance.address, 604800, 144000);
        const strategyInstance = await Strategy.deployed();
        await deployer.deploy(ERC20, 'test', 'testtoken');
        const rewardInstance = await ERC20.deployed();
        /*
    await deployer.deploy(
      Aggregator,
      bondMakerInstance.address,
      oracleInstance.address,
      pricerInstance.address,
      strategyInstance.address,
      rewardInstance.address,
      exchangeInstance.address,
      8,
      volOracleInstance.address,
      100000,
      10 ** 5
    );
    */
    }
};
