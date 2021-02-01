const fs = require('fs');

require('dotenv').config();

const Aggregator = artifacts.require('SimpleAggregatorCollateralizedEth');
const AggregatorERC20 = artifacts.require('SimpleAggregatorCollateralizedERC20');
const BondMakerHelper = artifacts.require('testBondRegistrator');
const BondMaker = artifacts.require('BondMakerCollateralizedEth');
const BondMakerERC20 = artifacts.require('EthBondMakerCollateralizedUsdc');
const Strategy = artifacts.require('StrategyForSimpleAggregatorETH');
const Exchange = artifacts.require('GeneralizedDotc');
const USDCOracle = artifacts.require('USDCOracle');
const Oracle = artifacts.require('TestOracle');
const PriceInverseOracle = artifacts.require('PriceInverseOracle');
const GeneralizedPricing = artifacts.require('GeneralizedPricing');
const Pricer = artifacts.require('BondPricerWithAcceptableMaturity');
const Detector = artifacts.require('DetectBondShape');
const TestUSDC = artifacts.require('TestUSDC');
const BT = artifacts.require('testBondToken');
const BTFactory = artifacts.require('BondTokenFactory');
const BTName = artifacts.require('BondTokenName');
const VolOracle = artifacts.require('HistoricalVolatilityOracle');

module.exports = async (deployer, network, accounts) => {
    // const { CORRECTIONFACTOR, TERM_LENGTH } = process.env;

    const spotPrice = 1000 * 10 ** 8;
    const volatility = 0.5 * 10 ** 8;
    const priceUnit = 10 * 10 ** 8;
    const callFirstRewardRate = 10 ** 8;
    const putFirstRewardRate = 10 ** 8;
    const maxSupplyDenominatorExponents = 8;
    const termLength = 604800;
    const correctionFactor = 144000;
    const feeTaker = accounts[2];

    console.group('{');
    // const collateralInstance = await TestUSDC.new();
    // console.log(`usdc: "${collateralInstance.address}"`);
    const usdOracleInstance = await USDCOracle.new();
    console.log(`usdPriceOracle: "${usdOracleInstance.address}"`);
    const oracleInstance = await Oracle.new(spotPrice, volatility);
    console.log(`ethPriceOracle: "${oracleInstance.address}"`);
    // const inverseOracleInstance = await PriceInverseOracle.new(oracleInstance.address);
    // console.log(`ethPriceInverseOracle: "${inverseOracleInstance.address}"`);
    const volOracleInstance = await VolOracle.new(oracleInstance.address);
    console.log(`ethVolatilityOracle: "${volOracleInstance.address}"`);
    const generalizedPricingInstance = await GeneralizedPricing.new();
    console.log(`generalizedPricing: "${generalizedPricingInstance.address}"`);
    const callPricerInstance = await Pricer.new(generalizedPricingInstance.address);
    console.log(`callPricer: "${callPricerInstance.address}"`);
    // const putPricerInstance = await Pricer.new(generalizedPricingInstance.address);
    // console.log(`putPricer: "${putPricerInstance.address}"`);
    const BTFactoryInstance = await BTFactory.new();
    console.log(`bondTokenFactory: "${BTFactoryInstance.address}"`);
    const BTNameInstance = await BTName.new();
    console.log(`bondTokenName: "${BTNameInstance.address}"`);
    const callBondMakerInstance = await BondMaker.new(
        oracleInstance.address,
        feeTaker,
        BTNameInstance.address,
        BTFactoryInstance.address,
        1
    );
    console.log(`bondMakerCollateralizedEth: "${callBondMakerInstance.address}"`);
    // const putBondMakerInstance = await BondMakerERC20.new(
    //     collateralInstance.address,
    //     inverseOracleInstance.address,
    //     feeTaker,
    //     BTNameInstance.address,
    //     BTFactoryInstance.address,
    //     1
    // );
    // console.log(`bondMakerCollateralizedErc20: "${putBondMakerInstance.address}"`);
    const detectorInstance = await Detector.new();
    console.log(`bondShapeDetector: "${detectorInstance.address}"`);
    const callExchangeInstance = await Exchange.new(
        callBondMakerInstance.address,
        volOracleInstance.address,
        usdOracleInstance.address,
        detectorInstance.address
    );
    console.log(`generalizedDotcCollateralizedEth: "${callExchangeInstance.address}"`);
    // const putExchangeInstance = await Exchange.new(
    //     putBondMakerInstance.address,
    //     volOracleInstance.address,
    //     oracleInstance.address,
    //     detectorInstance.address
    // );
    // console.log(`generalizedDotcCollateralizedErc20: "${putExchangeInstance.address}"`);
    const callStrategyInstance = await Strategy.new(
        callExchangeInstance.address,
        termLength,
        correctionFactor
    );
    console.log(`callStrategy: "${callStrategyInstance.address}"`);
    // const putStrategyInstance = await Strategy.new(
    //     putExchangeInstance.address,
    //     termLength,
    //     correctionFactor
    // );
    // console.log(`putStrategy: "${putStrategyInstance.address}"`);
    const bondMakerHelperInstance = await BondMakerHelper.new();
    console.log(`bondMakerHelper: "${bondMakerHelperInstance.address}"`);
    const rewardInstance = await BT.new();
    console.log(`rewardToken: "${rewardInstance.address}"`);

    const callAggregatorInstance = await Aggregator.new(
        oracleInstance.address,
        callPricerInstance.address,
        callStrategyInstance.address,
        rewardInstance.address,
        bondMakerHelperInstance.address,
        callExchangeInstance.address,
        volOracleInstance.address,
        priceUnit,
        callFirstRewardRate
    );
    console.log(`aggregatorEth: "${callAggregatorInstance.address}",`);
    if ((await callPricerInstance.owner()) !== callAggregatorInstance.address) {
        await callPricerInstance.transferOwnership(callAggregatorInstance.address);
    }

    // const putAggregatorInstance = await AggregatorERC20.new(
    //     oracleInstance.address,
    //     putPricerInstance.address,
    //     putStrategyInstance.address,
    //     rewardInstance.address,
    //     bondMakerHelperInstance.address,
    //     putExchangeInstance.address,
    //     collateralInstance.address,
    //     volOracleInstance.address,
    //     priceUnit,
    //     putFirstRewardRate,
    //     true
    // );
    // console.log(`aggregatorErc20: "${putAggregatorInstance.address}",`);
    // if ((await putPricerInstance.owner()) !== putAggregatorInstance.address) {
    //     await putPricerInstance.transferOwnership(putAggregatorInstance.address);
    // }

    await callStrategyInstance.registerAggregators(
        oracleInstance.address,
        false,
        [callAggregatorInstance.address],
        100,
        50
    );
    // await putStrategyInstance.registerAggregators(
    //     oracleInstance.address,
    //     true,
    //     [putAggregatorInstance.address],
    //     100,
    //     50
    // );
    console.log(`deployer: "${accounts[0]}"`);
    console.groupEnd();
    console.log('}');
    const output = {
        erc20: {
            address: '',
            contractName: 'ERC20',
        },
        bondToken: {
            address: '',
            contractName: 'BondTokenInterface',
        },
        // usdc: {
        //     address: collateralInstance.address,
        //     contractName: 'TestUSDC',
        // },
        rewardToken: {
            address: rewardInstance.address,
            contractName: 'testBondToken',
        },
        ethVolatilityOracle: {
            address: volOracleInstance.address,
            contractName: 'testVolatilityOracle',
        },
        ethPriceOracle: {
            address: oracleInstance.address,
            contractName: 'TestOracle',
        },
        // ethPriceInverseOracle: {
        //     address: inverseOracleInstance.address,
        //     contractName: 'PriceInverseOracle',
        // },
        generalizedPricing: {
            address: generalizedPricingInstance.address,
            contractName: 'GeneralizedPricing',
        },
        bondTokenFactory: {
            address: BTFactoryInstance.address,
            contractName: 'BondTokenFactory',
        },
        bondTokenName: {
            address: BTNameInstance.address,
            contractName: 'BondTokenName',
        },
        bondShapeDetector: {
            address: detectorInstance.address,
            contractName: 'DetectBondShape',
        },
        strategy: {
            address: callStrategyInstance.address,
            contractName: 'StrategyForSimpleAggregator',
        },
        // putStrategy: {
        //     address: putStrategyInstance.address,
        //     contractName: 'StrategyForSimpleAggregator',
        // },
        bondMakerHelper: {
            address: bondMakerHelperInstance.address,
            contractName: 'testBondRegistrator',
        },
        bondPricer: {
            address: callPricerInstance.address,
            contractName: 'BondPricerWithAcceptableMaturity',
        },
        // putBondPricer: {
        //     address: putPricerInstance.address,
        //     contractName: 'BondPricerWithAcceptableMaturity',
        // },
        callBondMaker: {
            address: callBondMakerInstance.address,
            contractName: 'BondMakerCollateralizedEth',
        },
        // putBondMaker: {
        //     address: putBondMakerInstance.address,
        //     contractName: 'EthBondMakerCollateralizedUsdc',
        // },
        callBondExchange: {
            address: callExchangeInstance.address,
            contractName: 'GeneralizedDotc',
        },
        // putBondExchange: {
        //     address: putExchangeInstance.address,
        //     contractName: 'GeneralizedDotc',
        // },
        callAggregator: {
            address: callAggregatorInstance.address,
            contractName: 'SimpleAggregatorCollateralizedEth',
        },
        // putAggregator: {
        //     address: putAggregatorInstance.address,
        //     contractName: 'SimpleAggregatorCollateralizedErc20',
        // },
    };

    const outputFileName = process.env.OUTPUT_FILE || 'dump.json';
    fs.writeFileSync(outputFileName, JSON.stringify(output, null, 2));
};
