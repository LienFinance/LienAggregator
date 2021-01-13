const BondMaker = artifacts.require("TestBondMaker");
const Aggregator = artifacts.require("testSimpleAggregatorCollateralizedEth");
const Strategy = artifacts.require("StrategyForSimpleAggregator");
const Exchange = artifacts.require("TestExchange");
const VolOracle = artifacts.require("testVolatilityOracle");
const Oracle = artifacts.require("testOracleForAggregator");
const Pricer = artifacts.require("testGeneralizedPricing");

module.exports = async (deployer, network) => {
  if (network != "ropsten" && network != "mainnet") {
    await deployer.deploy(Exchange);
    const exchangeInstance = await Exchange.deployed();
    await deployer.deploy(Oracle);
    const oracleInstance = await Oracle.deployed();
    await deployer.deploy(Pricer);
    const pricerInstance = await Pricer.deployed();
    await deployer.deploy(VolOracle);
    const volOracleInstance = await VolOracle.deployed();
    await deployer.deploy(BondMaker);
    const bondMakerInstance = await BondMaker.deployed();
    await deployer.deploy(Strategy, exchangeInstance.address, 608000, 144000);
    const strategyInstance = await Strategy.deployed();
    await deployer.deploy(
      Aggregator,
      bondMakerInstance.address,
      oracleInstance.address,
      pricerInstance.address,
      strategyInstance.address,
      exchangeInstance.address,
      8,
      volOracleInstance.address,
      100000
    );
  }
};
