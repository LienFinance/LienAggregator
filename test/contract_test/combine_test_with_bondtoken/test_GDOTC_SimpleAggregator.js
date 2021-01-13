const ZAddress = "0x0000000000000000000000000000000000000000";
const ZBytes32 =
  "0x0000000000000000000000000000000000000000000000000000000000000000";
const Factory = artifacts.require("AggregatorFactoryCollateralizedEth");
const Aggregator = artifacts.require("testSimpleAggregatorCollateralizedEth");
const AggregatorERC20 = artifacts.require(
  "testSimpleAggregatorCollateralizedERC20"
);
const BondMaker = artifacts.require("BondMakerCollateralizedEth");
const Strategy = artifacts.require("MockSimpleStrategy2");
const Exchange = artifacts.require("GeneralizedDotc");
const Oracle = artifacts.require("testOracleForAggregator");
const Pricer = artifacts.require("testGeneralizedPricing");
const Detector = artifacts.require("DetectBondShape");
const Generator = artifacts.require("fnMapGenerator");
const BT = artifacts.require("testBondToken");
const BTFactory = artifacts.require("BondTokenFactory");
const BTName = artifacts.require("BondTokenName");
const VolOracle = artifacts.require("testVolatilityOracle");
const { time, expectRevert } = require("@openzeppelin/test-helpers");
let setBond = require("../../utils/setBond.js");
const priceUnit = 1000000000;

contract("ETH aggregator", function (accounts) {
  const termInterval = 608000; // 1 week in sec
  const aggregatorLength = termInterval * 3 - 3600 * 12;
  const termCorrectionFactor = 144000; // Friday 16:00 UTC
  const aggregatorType = "Normal LBT";
  let exchangeInstance;
  let volOracleInstance;
  let oracleInstance;
  let pricerInstance;
  let bondMakerInstance;
  let strategyInstance;
  let aggregatorInstance;
  let maturity;
  let strikePrice;
  let BTNameInstance;
  let BTFactoryInstance;
  let generatorInstance;
  let detectorInstance;
  const BaseBondsInfo = {
    ethPrice: 400,
    ethVolatility: 40,
    untilMaturity: 0.1,
    strikePriceSBT: 200,
    strikePriceCall: 400,
    Lev2EndPoint: 600,
    SBTPrice: 199.9339221,
    CallPrice: 40.26272458,
    VolShortPrice: 61.19286201,
    Lev2Price: 98.61049129,
  };

  beforeEach(async () => {
    volOracleInstance = await VolOracle.new();
    oracleInstance = await Oracle.new();
    pricerInstance = await Pricer.new();
    BTFactoryInstance = await BTFactory.new();
    BTNameInstance = await BTName.new();
    detectorInstance = await Detector.new();
    bondMakerInstance = await BondMaker.new(
      oracleInstance.address,
      accounts[0],
      BTNameInstance.address,
      BTFactoryInstance.address,
      1
    );
    exchangeInstance = await Exchange.new(
      bondMakerInstance.address,
      volOracleInstance.address,
      oracleInstance.address,
      detectorInstance.address
    );
    strategyInstance = await Strategy.new();
    generatorInstance = await Generator.new();
    maturity = await strategyInstance.calcNextMaturity();
    const oracleData = await oracleInstance.getData();
    strikePrice = await strategyInstance.getCurrentStrikePrice(
      maturity,
      oracleData[0].toString(),
      oracleData[1].toString(),
      priceUnit
    );

    aggregatorInstance = await Aggregator.new(
      bondMakerInstance.address,
      oracleInstance.address,
      pricerInstance.address,
      strategyInstance.address,
      exchangeInstance.address,
      8,
      volOracleInstance.address,
      priceUnit
    );
  });

  describe("check default pool", function () {
    it("check eth sell pool", async function () {
      const poolID = await exchangeInstance.generateVsEthPoolID(
        aggregatorInstance.address,
        true
      );
      const poolData = await exchangeInstance.getVsEthPool(poolID);
      assert.equal(
        poolData[0],
        aggregatorInstance.address,
        "Invalid seller Address"
      );
      assert.equal(
        poolData[1],
        oracleInstance.address,
        "Invalid oracle Address"
      );
      assert.equal(
        poolData[2],
        pricerInstance.address,
        "Invalid pricer Address"
      );
      assert.equal(poolData[3], 100, "Invalid feebase");
      assert(poolData[4], "This pool should be sell");
    });

    it("check eth buy pool", async function () {
      const poolID = await exchangeInstance.generateVsEthPoolID(
        aggregatorInstance.address,
        false
      );
      const poolData = await exchangeInstance.getVsEthPool(poolID);
      assert.equal(
        poolData[0],
        aggregatorInstance.address,
        "Invalid seller Address"
      );
      assert.equal(
        poolData[1],
        oracleInstance.address,
        "Invalid bondmaker Address"
      );
      assert.equal(
        poolData[2],
        pricerInstance.address,
        "Invalid pricer Address"
      );
      assert.equal(poolData[3], 100, "Invalid feebase");
      assert(!poolData[4], "This pool should be buy");
    });

    it("check bond pool", async function () {
      const poolID = await exchangeInstance.generateVsBondPoolID(
        aggregatorInstance.address,
        bondMakerInstance.address
      );
      const poolData = await exchangeInstance.getVsBondPool(poolID);
      assert.equal(
        poolData[0],
        aggregatorInstance.address,
        "Invalid seller Address"
      );
      assert.equal(
        poolData[1],
        bondMakerInstance.address,
        "Invalid bondmaker Address"
      );
      assert.equal(
        poolData[2],
        volOracleInstance.address,
        "Invalid volOracle Address"
      );
      assert.equal(
        poolData[3],
        pricerInstance.address,
        "Invalid pricer Address #1"
      );
      assert.equal(
        poolData[4],
        pricerInstance.address,
        "Invalid pricer Address #2"
      );
      assert.equal(poolData[5], 100, "Invalid feebase");
    });
  });

  describe("chenge spread", function () {
    beforeEach(async () => {
      await strategyInstance.changeSpread(50);
      await time.increaseTo(maturity - 70000);
      await aggregatorInstance.changeSpread();
    });

    it("check eth sell pool", async function () {
      const poolID = await exchangeInstance.generateVsEthPoolID(
        aggregatorInstance.address,
        true
      );
      const poolData = await exchangeInstance.getVsEthPool(poolID);
      assert.equal(
        poolData[0],
        aggregatorInstance.address,
        "Invalid seller Address"
      );
      assert.equal(
        poolData[1],
        oracleInstance.address,
        "Invalid bondmaker Address"
      );
      assert.equal(
        poolData[2],
        pricerInstance.address,
        "Invalid pricer Address"
      );
      assert.equal(poolData[3], 50, "Invalid feebase");
      assert(poolData[4], "This pool should be sell");
    });

    it("check eth buy pool", async function () {
      const poolID = await exchangeInstance.generateVsEthPoolID(
        aggregatorInstance.address,
        false
      );
      const poolData = await exchangeInstance.getVsEthPool(poolID);
      assert.equal(
        poolData[0],
        aggregatorInstance.address,
        "Invalid seller Address"
      );
      assert.equal(
        poolData[1],
        oracleInstance.address,
        "Invalid bondmaker Address"
      );
      assert.equal(
        poolData[2],
        pricerInstance.address,
        "Invalid pricer Address"
      );
      assert.equal(poolData[3], 50, "Invalid feebase");
      assert(!poolData[4], "This pool should be buy");
    });
    it("check bond pool", async function () {
      const poolID = await exchangeInstance.generateVsBondPoolID(
        aggregatorInstance.address,
        bondMakerInstance.address
      );
      const poolData = await exchangeInstance.getVsBondPool(poolID);
      assert.equal(
        poolData[0],
        aggregatorInstance.address,
        "Invalid seller Address"
      );
      assert.equal(
        poolData[1],
        bondMakerInstance.address,
        "Invalid bondmaker Address"
      );
      assert.equal(
        poolData[2],
        volOracleInstance.address,
        "Invalid volOracle Address"
      );
      assert.equal(
        poolData[3],
        pricerInstance.address,
        "Invalid pricer Address #1"
      );
      assert.equal(
        poolData[4],
        pricerInstance.address,
        "Invalid pricer Address #2"
      );
      assert.equal(poolData[5], 50, "Invalid feebase");
    });
  });

  describe("tranche bonds and liquidateBonds", function () {
    beforeEach(async function () {
      await aggregatorInstance.addLiquidity({
        value: web3.utils.toWei("1", "ether"),
      });
      await aggregatorInstance.renewMaturity();
    });
    it("check tranche bonds", async function () {
      await time.increaseTo(maturity.toNumber() - 100000);
      await aggregatorInstance.trancheBonds();
      const ethAllowance = await exchangeInstance.ethAllowance(
        aggregatorInstance.address
      );
      assert.equal(
        "100000000000000000",
        ethAllowance.toString(),
        "Invalid ETH Allowance"
      );
    });
    it("check liquidate bonds", async function () {
      await time.increaseTo(maturity.toNumber() - 100000);
      await aggregatorInstance.trancheBonds();
      await time.increaseTo(maturity.toNumber() + 100);
      await aggregatorInstance.liquidateBonds();
      const ethAllowance = await exchangeInstance.ethAllowance(
        aggregatorInstance.address
      );
      console.log("ETH Allowance: " + ethAllowance.toString());
      assert.equal("0", ethAllowance.toString(), "Invalid ETH Allowance");
      const ethBalance = await web3.eth.getBalance(aggregatorInstance.address);
      assert.equal(
        "1000000000000000000",
        ethBalance.toString(),
        "Invalid ETH Allowance"
      );
    });
  });
});

contract("ERC20 aggregator", function (accounts) {
  const termInterval = 608000; // 1 week in sec
  const aggregatorLength = termInterval * 3 - 3600 * 12;
  const termCorrectionFactor = 144000; // Friday 16:00 UTC
  const aggregatorType = "Normal LBT";
  let exchangeInstance;
  let volOracleInstance;
  let oracleInstance;
  let pricerInstance;
  let bondMakerInstance;
  let strategyInstance;
  let aggregatorInstance;
  let maturity;
  let strikePrice;
  let BTNameInstance;
  let BTFactoryInstance;
  let generatorInstance;
  let detectorInstance;
  let collateralInstance;

  beforeEach(async () => {
    volOracleInstance = await VolOracle.new();
    oracleInstance = await Oracle.new();
    pricerInstance = await Pricer.new();
    BTFactoryInstance = await BTFactory.new();
    BTNameInstance = await BTName.new();
    detectorInstance = await Detector.new();
    bondMakerInstance = await BondMaker.new(
      oracleInstance.address,
      accounts[0],
      BTNameInstance.address,
      BTFactoryInstance.address,
      1
    );
    exchangeInstance = await Exchange.new(
      bondMakerInstance.address,
      volOracleInstance.address,
      oracleInstance.address,
      detectorInstance.address
    );
    strategyInstance = await Strategy.new();
    generatorInstance = await Generator.new();
    maturity = await strategyInstance.calcNextMaturity();
    collateralInstance = await BT.new();

    aggregatorInstance = await AggregatorERC20.new(
      bondMakerInstance.address,
      oracleInstance.address,
      pricerInstance.address,
      strategyInstance.address,
      exchangeInstance.address,
      8,
      collateralInstance.address,
      volOracleInstance.address,
      priceUnit
    );
  });

  describe("check default pool", function () {
    it("check erc20 sell pool", async function () {
      const poolID = await exchangeInstance.generateVsErc20PoolID(
        aggregatorInstance.address,
        collateralInstance.address,
        true
      );
      const poolData = await exchangeInstance.getVsErc20Pool(poolID);
      assert.equal(
        poolData[0],
        aggregatorInstance.address,
        "Invalid seller Address"
      );
      assert.equal(
        poolData[1],
        collateralInstance.address,
        "Invalid ERC20 collateral Address"
      );
      assert.equal(
        poolData[2],
        oracleInstance.address,
        "Invalid bondmaker Address"
      );
      assert.equal(
        poolData[3],
        pricerInstance.address,
        "Invalid pricer Address"
      );
      assert.equal(poolData[4], 100, "Invalid feebase");
      assert(poolData[5], "This pool should be sell");
    });

    it("check erc20 buy pool", async function () {
      const poolID = await exchangeInstance.generateVsErc20PoolID(
        aggregatorInstance.address,
        collateralInstance.address,
        false
      );
      const poolData = await exchangeInstance.getVsErc20Pool(poolID);
      assert.equal(
        poolData[0],
        aggregatorInstance.address,
        "Invalid seller Address"
      );
      assert.equal(
        poolData[1],
        collateralInstance.address,
        "Invalid ERC20 collateral Address"
      );
      assert.equal(
        poolData[2],
        oracleInstance.address,
        "Invalid bondmaker Address"
      );
      assert.equal(
        poolData[3],
        pricerInstance.address,
        "Invalid pricer Address"
      );
      assert.equal(poolData[4], 100, "Invalid feebase");
      assert(!poolData[5], "This pool should be buy");
    });
    it("check bond pool", async function () {
      const poolID = await exchangeInstance.generateVsBondPoolID(
        aggregatorInstance.address,
        bondMakerInstance.address
      );
      const poolData = await exchangeInstance.getVsBondPool(poolID);
      assert.equal(
        poolData[0],
        aggregatorInstance.address,
        "Invalid seller Address"
      );
      assert.equal(
        poolData[1],
        bondMakerInstance.address,
        "Invalid bondmaker Address"
      );
      assert.equal(
        poolData[2],
        volOracleInstance.address,
        "Invalid volOracle Address"
      );
      assert.equal(
        poolData[3],
        pricerInstance.address,
        "Invalid pricer Address #1"
      );
      assert.equal(
        poolData[4],
        pricerInstance.address,
        "Invalid pricer Address #2"
      );
      assert.equal(poolData[5], 100, "Invalid feebase");
    });
  });

  describe("chenge spread", function () {
    beforeEach(async () => {
      await strategyInstance.changeSpread(50);
      await time.increaseTo(maturity - 70000);
      await aggregatorInstance.changeSpread();
    });

    it("check erc20 sell pool", async function () {
      const poolID = await exchangeInstance.generateVsErc20PoolID(
        aggregatorInstance.address,
        collateralInstance.address,
        true
      );
      const poolData = await exchangeInstance.getVsErc20Pool(poolID);
      assert.equal(poolData[4], 50, "Invalid feebase");
    });

    it("check erc20 buy pool", async function () {
      const poolID = await exchangeInstance.generateVsErc20PoolID(
        aggregatorInstance.address,
        collateralInstance.address,
        true
      );
      const poolData = await exchangeInstance.getVsErc20Pool(poolID);
      assert.equal(poolData[4], 50, "Invalid feebase");
    });
    it("check bond pool", async function () {
      const poolID = await exchangeInstance.generateVsBondPoolID(
        aggregatorInstance.address,
        bondMakerInstance.address
      );
      const poolData = await exchangeInstance.getVsBondPool(poolID);
      assert.equal(poolData[5], 50, "Invalid feebase");
    });
  });
});
