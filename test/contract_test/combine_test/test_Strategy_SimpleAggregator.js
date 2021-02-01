const ZAddress = "0x0000000000000000000000000000000000000000";
const BondMaker = artifacts.require("TestBondMaker");
const BondMakerERC20 = artifacts.require("TestERC20BondMaker");
const Aggregator = artifacts.require("testSimpleAggregatorCollateralizedEth");
const AggregatorERC20 = artifacts.require(
  "testSimpleAggregatorCollateralizedERC20"
);

const BigNumber = require("bignumber.js");
const BT = artifacts.require("testBondToken");

const Strategy = artifacts.require("StrategyForSimpleAggregator");
const StrategyETH = artifacts.require("StrategyForSimpleAggregatorETH");
const Exchange = artifacts.require("TestExchange");
const VolOracle = artifacts.require("testVolatilityOracle");
const Oracle = artifacts.require("testOracleForAggregator");
const GeneralizedPricing = artifacts.require("GeneralizedPricing");
const Pricer = artifacts.require("BondPricerWithAcceptableMaturity");
const Registrator = artifacts.require("testBondRegistrator");
const { time, expectRevert } = require("@openzeppelin/test-helpers");
let setBond = require("../../utils/setBond.js");
const fs = require("fs");
const priceUnit = 1000000000;

contract("Combine test: STRATEGY-ETHAggregator", function (accounts) {
  const termInterval = 604800; // 1 week in sec
  const aggregatorLength = termInterval * 3 - 3600 * 12;
  const termCorrectionFactor = 144000; // Friday 16:00 UTC
  const aggregatorType = "Normal LBT";
  let volOracleInstance;
  let exchangeInstance;
  let oracleInstance;
  let pricerInstance;
  let bondMakerInstance;
  let strategyInstance;
  let aggregatorInstance;
  let maturity;
  let strikePrice;
  let rewardInstance;
  let registratorInstance;
  beforeEach(async () => {
    volOracleInstance = await VolOracle.new();
    bondMakerInstance = await BondMaker.new();
    exchangeInstance = await Exchange.new(bondMakerInstance.address);
    oracleInstance = await Oracle.new();
    const generalizedPricer = await GeneralizedPricing.new();
    pricerInstance = await Pricer.new(generalizedPricer.address);
    registratorInstance = await Registrator.new();
    rewardInstance = await BT.new();
    strategyInstance = await StrategyETH.new(
      exchangeInstance.address,
      604800,
      144000
    );
    maturity = await strategyInstance.calcNextMaturity();
    const oracleData = await oracleInstance.getData();
    strikePrice = await strategyInstance.getCurrentStrikePrice(
      oracleData[0].toString(),
      priceUnit,
      false
    );
    aggregatorInstance = await Aggregator.new(
      oracleInstance.address,
      pricerInstance.address,
      strategyInstance.address,
      rewardInstance.address,
      registratorInstance.address,
      exchangeInstance.address,
      volOracleInstance.address,
      priceUnit
    );
    await pricerInstance.transferOwnership(aggregatorInstance.address);
    await strategyInstance.registerAggregators(
      oracleInstance.address,
      false,
      [aggregatorInstance.address],
      100,
      50
    );
  });

  describe("Aggregator-Strategy", function () {
    const inputFile = "test/contract_test/unit_test/Strategy/testCases.json";
    const data = JSON.parse(fs.readFileSync(inputFile, "utf8"));

    describe("Tranche Bond", function () {
      describe("first tranche", function () {
        let bondIDs1;
        beforeEach(async () => {
          await bondMakerInstance.sendTransaction({
            from: accounts[0],
            value: web3.utils.toWei("2", "ether"),
          });
          await aggregatorInstance.addLiquidity({
            value: 1000 * 10 ** 10,
          });
          await oracleInstance.changePriceAndVolatility(
            400 * 10 ** 8,
            10 * 10 ** 6
          );
          await aggregatorInstance.renewMaturity();
          await aggregatorInstance.trancheBonds();
          const BG1Info = await bondMakerInstance.getBondGroup(1);
          bondIDs1 = BG1Info[0];
        });

        it("check bond group number", async function () {
          const bondIndex = await bondMakerInstance.getBondIndex();
          assert.equal(
            bondIndex.toString(),
            "1",
            "invalid bond group id returned: " + bondIndex.toString()
          );
        });
        it("check sbt amount", async function () {
          const BondInfo = await bondMakerInstance.getBond(bondIDs1[0]);
          const Bond = await BT.at(BondInfo[0]);
          const amount = await Bond.balanceOf(aggregatorInstance.address);
          assert.equal(
            amount.toString(),
            "200",
            "Invalid bondAmount returned: " + amount.toString()
          );
        });
        it("check call amount", async function () {
          const BondInfo = await bondMakerInstance.getBond(bondIDs1[1]);
          const Bond = await BT.at(BondInfo[0]);
          const amount = await Bond.balanceOf(aggregatorInstance.address);
          assert.equal(
            amount.toString(),
            "200",
            "Invalid bondAmount returned: " + amount.toString()
          );
        });
        it("check lev2 amount", async function () {
          const BondInfo = await bondMakerInstance.getBond(bondIDs1[2]);
          const Bond = await BT.at(BondInfo[0]);
          const amount = await Bond.balanceOf(aggregatorInstance.address);
          assert.equal(
            amount.toString(),
            "200",
            "Invalid bondAmount returned: " + amount.toString()
          );
        });
        it("check vol short amount", async function () {
          const BondInfo = await bondMakerInstance.getBond(bondIDs1[3]);
          const Bond = await BT.at(BondInfo[0]);
          const amount = await Bond.balanceOf(aggregatorInstance.address);
          assert.equal(
            amount.toString(),
            "200",
            "Invalid bondAmount returned: " + amount.toString()
          );
        });

        describe("second tranche", async function () {
          let bondIDs2;
          beforeEach(async () => {
            await time.increase(3600 * 24 * 3 + 100);
            await oracleInstance.changePriceAndVolatility(
              800 * 10 ** 8,
              10 * 10 ** 6
            );
            await aggregatorInstance.trancheBonds();
            const BG1Info = await bondMakerInstance.getBondGroup(2);
            bondIDs2 = BG1Info[0];
          });
          it("check bond group number", async function () {
            const bondIndex = await bondMakerInstance.getBondIndex();
            assert.equal(
              bondIndex.toString(),
              "2",
              "invalid bond group id returned: " + bondIndex.toString()
            );
          });
          it("check sbt amount", async function () {
            const BondInfo = await bondMakerInstance.getBond(bondIDs1[0]);
            const Bond = await BT.at(BondInfo[0]);
            const amount = await Bond.balanceOf(aggregatorInstance.address);
            assert.equal(
              amount.toString(),
              "379",
              "Invalid bondAmount returned: " + amount.toString()
            );
          });
          it("check first call amount", async function () {
            const BondInfo = await bondMakerInstance.getBond(bondIDs1[1]);
            const Bond = await BT.at(BondInfo[0]);
            const amount = await Bond.balanceOf(aggregatorInstance.address);
            assert.equal(
              amount.toString(),
              "0",
              "Invalid bondAmount returned: " + amount.toString()
            );
          });
          it("check first lev2 amount", async function () {
            const BondInfo = await bondMakerInstance.getBond(bondIDs1[2]);
            const Bond = await BT.at(BondInfo[0]);
            const amount = await Bond.balanceOf(aggregatorInstance.address);
            assert.equal(
              amount.toString(),
              "0",
              "Invalid bondAmount returned: " + amount.toString()
            );
          });
          it("check first vol short amount", async function () {
            const BondInfo = await bondMakerInstance.getBond(bondIDs1[3]);
            const Bond = await BT.at(BondInfo[0]);
            const amount = await Bond.balanceOf(aggregatorInstance.address);
            assert.equal(
              amount.toString(),
              "0",
              "Invalid bondAmount returned: " + amount.toString()
            );
          });

          it("check first call amount", async function () {
            const BondInfo = await bondMakerInstance.getBond(bondIDs2[1]);
            const Bond = await BT.at(BondInfo[0]);
            const amount = await Bond.balanceOf(aggregatorInstance.address);
            assert.equal(
              amount.toString(),
              "179",
              "Invalid bondAmount returned: " + amount.toString()
            );
          });
          it("check first lev2 amount", async function () {
            const BondInfo = await bondMakerInstance.getBond(bondIDs2[2]);
            const Bond = await BT.at(BondInfo[0]);
            const amount = await Bond.balanceOf(aggregatorInstance.address);
            assert.equal(
              amount.toString(),
              "179",
              "Invalid bondAmount returned: " + amount.toString()
            );
          });
          it("check first vol short amount", async function () {
            const BondInfo = await bondMakerInstance.getBond(bondIDs2[3]);
            const Bond = await BT.at(BondInfo[0]);
            const amount = await Bond.balanceOf(aggregatorInstance.address);
            assert.equal(
              amount.toString(),
              "179",
              "Invalid bondAmount returned: " + amount.toString()
            );
          });
        });
      });
    });
  });
});

contract("Combine test: STRATEGY-ERC20Aggregator", function (accounts) {
  const termInterval = 604800; // 1 week in sec
  const aggregatorLength = termInterval * 3 - 3600 * 12;
  const termCorrectionFactor = 144000; // Friday 16:00 UTC
  const aggregatorType = "Normal LBT";
  let volOracleInstance;
  let exchangeInstance;
  let oracleInstance;
  let pricerInstance;
  let bondMakerInstance;
  let strategyInstance;
  let aggregatorInstance;
  let collateralInstance;
  let maturity;
  let strikePrice;
  let rewardInstance;
  let registratorInstance;
  const lot = 10 ** 6;
  beforeEach(async () => {
    volOracleInstance = await VolOracle.new();
    oracleInstance = await Oracle.new();
    const generalizedPricer = await GeneralizedPricing.new();
    pricerInstance = await Pricer.new(generalizedPricer.address);
    collateralInstance = await BT.new();
    await collateralInstance.changeDecimal(8);
    await collateralInstance.mint(accounts[0], lot * 10);
    registratorInstance = await Registrator.new();
    rewardInstance = await BT.new();

    await oracleInstance.changePriceAndVolatility(400 * 10 ** 8, 80 * 10 ** 6);

    bondMakerInstance = await BondMakerERC20.new(collateralInstance.address);
    exchangeInstance = await Exchange.new(bondMakerInstance.address);

    strategyInstance = await Strategy.new(604800, 144000);
    maturity = await strategyInstance.calcNextMaturity();
    const strikePrice = await strategyInstance.getCurrentStrikePrice(
      400 * 10 ** 8,
      priceUnit,
      true
    );
    aggregatorInstance = await AggregatorERC20.new(
      oracleInstance.address,
      pricerInstance.address,
      strategyInstance.address,
      rewardInstance.address,
      registratorInstance.address,
      exchangeInstance.address,
      collateralInstance.address,
      volOracleInstance.address,
      priceUnit,
      new BigNumber(10 ** 10),
      true
    );

    await pricerInstance.transferOwnership(aggregatorInstance.address);

    await strategyInstance.registerAggregators(
      oracleInstance.address,
      true,
      [aggregatorInstance.address],
      100,
      50
    );
    await collateralInstance.approve(aggregatorInstance.address, lot * 10);

    await collateralInstance.approve(bondMakerInstance.address, lot * 10);
  });

  describe("Aggregator-Strategy", function () {
    const inputFile = "test/contract_test/unit_test/Strategy/testCases.json";
    const data = JSON.parse(fs.readFileSync(inputFile, "utf8"));

    describe("Tranche Bond", function () {
      describe("first tranche", function () {
        let bondIDs1;
        beforeEach(async () => {
          await collateralInstance.transfer(bondMakerInstance.address, 100000);
          await aggregatorInstance.addLiquidity(1000);
          await oracleInstance.changePriceAndVolatility(
            400 * 10 ** 8,
            10 * 10 ** 6
          );
          await aggregatorInstance.renewMaturity();
          await aggregatorInstance.trancheBonds();
          const BG1Info = await bondMakerInstance.getBondGroup(1);
          bondIDs1 = BG1Info[0];
        });

        it("check bond group number", async function () {
          const bondIndex = await bondMakerInstance.getBondIndex();
          assert.equal(
            bondIndex.toString(),
            "1",
            "invalid bond group id returned: " + bondIndex.toString()
          );
        });
        it("check sbt amount", async function () {
          const BondInfo = await bondMakerInstance.getBond(bondIDs1[0]);
          const Bond = await BT.at(BondInfo[0]);
          const amount = await Bond.balanceOf(aggregatorInstance.address);
          assert.equal(
            amount.toString(),
            "200",
            "Invalid bondAmount returned: " + amount.toString()
          );
        });
        it("check call amount", async function () {
          const BondInfo = await bondMakerInstance.getBond(bondIDs1[1]);
          const Bond = await BT.at(BondInfo[0]);
          const amount = await Bond.balanceOf(aggregatorInstance.address);
          assert.equal(
            amount.toString(),
            "200",
            "Invalid bondAmount returned: " + amount.toString()
          );
        });
        it("check lev2 amount", async function () {
          const BondInfo = await bondMakerInstance.getBond(bondIDs1[2]);
          const Bond = await BT.at(BondInfo[0]);
          const amount = await Bond.balanceOf(aggregatorInstance.address);
          assert.equal(
            amount.toString(),
            "200",
            "Invalid bondAmount returned: " + amount.toString()
          );
        });
        it("check vol short amount", async function () {
          const BondInfo = await bondMakerInstance.getBond(bondIDs1[3]);
          const Bond = await BT.at(BondInfo[0]);
          const amount = await Bond.balanceOf(aggregatorInstance.address);
          assert.equal(
            amount.toString(),
            "200",
            "Invalid bondAmount returned: " + amount.toString()
          );
        });

        describe("second tranche", async function () {
          let bondIDs2;
          beforeEach(async () => {
            await time.increase(3600 * 24 * 3 + 100);
            await oracleInstance.changePriceAndVolatility(
              800 * 10 ** 8,
              10 * 10 ** 6
            );
            await aggregatorInstance.trancheBonds();
            const BG1Info = await bondMakerInstance.getBondGroup(2);
            bondIDs2 = BG1Info[0];
          });
          it("check bond group number", async function () {
            const bondIndex = await bondMakerInstance.getBondIndex();
            assert.equal(
              bondIndex.toString(),
              "2",
              "invalid bond group id returned: " + bondIndex.toString()
            );
          });
          it("check sbt amount", async function () {
            const BondInfo = await bondMakerInstance.getBond(bondIDs1[0]);
            const Bond = await BT.at(BondInfo[0]);
            const amount = await Bond.balanceOf(aggregatorInstance.address);
            assert.equal(
              amount.toString(),
              "400",
              "Invalid bondAmount returned: " + amount.toString()
            );
          });
          it("check first call amount", async function () {
            const BondInfo = await bondMakerInstance.getBond(bondIDs1[1]);
            const Bond = await BT.at(BondInfo[0]);
            const amount = await Bond.balanceOf(aggregatorInstance.address);
            assert.equal(
              amount.toString(),
              "0",
              "Invalid bondAmount returned: " + amount.toString()
            );
          });
          it("check first lev2 amount", async function () {
            const BondInfo = await bondMakerInstance.getBond(bondIDs1[2]);
            const Bond = await BT.at(BondInfo[0]);
            const amount = await Bond.balanceOf(aggregatorInstance.address);
            assert.equal(
              amount.toString(),
              "0",
              "Invalid bondAmount returned: " + amount.toString()
            );
          });
          it("check first vol short amount", async function () {
            const BondInfo = await bondMakerInstance.getBond(bondIDs1[3]);
            const Bond = await BT.at(BondInfo[0]);
            const amount = await Bond.balanceOf(aggregatorInstance.address);
            assert.equal(
              amount.toString(),
              "0",
              "Invalid bondAmount returned: " + amount.toString()
            );
          });

          it("check first call amount", async function () {
            const BondInfo = await bondMakerInstance.getBond(bondIDs2[1]);
            const Bond = await BT.at(BondInfo[0]);
            const amount = await Bond.balanceOf(aggregatorInstance.address);
            assert.equal(
              amount.toString(),
              "200",
              "Invalid bondAmount returned: " + amount.toString()
            );
          });
          it("check first lev2 amount", async function () {
            const BondInfo = await bondMakerInstance.getBond(bondIDs2[2]);
            const Bond = await BT.at(BondInfo[0]);
            const amount = await Bond.balanceOf(aggregatorInstance.address);
            assert.equal(
              amount.toString(),
              "200",
              "Invalid bondAmount returned: " + amount.toString()
            );
          });
          it("check first vol short amount", async function () {
            const BondInfo = await bondMakerInstance.getBond(bondIDs2[3]);
            const Bond = await BT.at(BondInfo[0]);
            const amount = await Bond.balanceOf(aggregatorInstance.address);
            assert.equal(
              amount.toString(),
              "200",
              "Invalid bondAmount returned: " + amount.toString()
            );
          });
        });
      });
    });
  });
});
