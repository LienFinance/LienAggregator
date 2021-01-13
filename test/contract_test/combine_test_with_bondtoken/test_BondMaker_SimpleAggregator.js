const ZAddress = "0x0000000000000000000000000000000000000000";
const ZBytes32 =
  "0x0000000000000000000000000000000000000000000000000000000000000000";
const Aggregator = artifacts.require("testSimpleAggregatorCollateralizedEth");
const AggregatorERC20 = artifacts.require(
  "testSimpleAggregatorCollateralizedERC20"
);
const BondMaker = artifacts.require("BondMakerCollateralizedEth");
const BondMakerERC20 = artifacts.require("BondMakerCollateralizedErc20");
const Strategy = artifacts.require("StrategyForSimpleAggregator");
const MockAggregator = artifacts.require("MockSimpleAggregator");
const Exchange = artifacts.require("TestExchange");
const Oracle = artifacts.require("testOracleForAggregator");
const Pricer = artifacts.require("testGeneralizedPricing");
const Generator = artifacts.require("fnMapGenerator");
const BT = artifacts.require("BondToken");
const testBT = artifacts.require("testBondToken");
const BTFactory = artifacts.require("BondTokenFactory");
const BTName = artifacts.require("BondTokenName");
const VolOracle = artifacts.require("testVolatilityOracle");
const { time, expectRevert } = require("@openzeppelin/test-helpers");
let setBond = require("../../utils/setBond.js");
const fs = require("fs");
const inputFile = "test/contract_test/unit_test/Strategy/testCases.json";
const data = JSON.parse(fs.readFileSync(inputFile, "utf8"));
const priceMultiplyer = 10 ** 8;

contract("Combine test with unittest", function (accounts) {
  const termInterval = 608000; // 1 week in sec
  const aggregatorLength = termInterval * 3 - 3600 * 12;
  const termCorrectionFactor = 144000; // Friday 16:00 UTC
  const aggregatorType = "Normal LBT";
  const priceUnit = 1000000000;
  let aggregatorInstance;
  let exchangeInstance;
  let volOracleInstance;
  let oracleInstance;
  let pricerInstance;
  let bondMakerInstance;
  let strategyInstance;
  let maturity;
  let strikePrice;
  let BTNameInstance;
  let BTFactoryInstance;
  let generatorInstance;
  beforeEach(async () => {
    volOracleInstance = await VolOracle.new();
    exchangeInstance = await Exchange.new();
    oracleInstance = await Oracle.new();
    pricerInstance = await Pricer.new();
    BTFactoryInstance = await BTFactory.new();
    BTNameInstance = await BTName.new();
    bondMakerInstance = await BondMaker.new(
      oracleInstance.address,
      accounts[0],
      BTNameInstance.address,
      BTFactoryInstance.address,
      1
    );
    strategyInstance = await Strategy.new(
      exchangeInstance.address,
      608000,
      144000
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
    generatorInstance = await Generator.new();
    maturity = await strategyInstance.calcNextMaturity();
    const oracleData = await oracleInstance.getData();
    strikePrice = await strategyInstance.getCurrentStrikePrice(
      maturity,
      oracleData[0].toString(),
      oracleData[1].toString(),
      priceUnit
    );
  });

  describe("isValidLBT", function () {
    for (let i = 0; i < 2; i++) {
      it("valid LBT", async function () {
        const testCase = data.validCases[i];
        await setBond.registerBondGroupForRBM(
          testCase,
          maturity.toNumber(),
          bondMakerInstance,
          generatorInstance,
          undefined
        );
        const isValidLBT = await strategyInstance.isValidLBT(
          bondMakerInstance.address,
          2,
          testCase.ethPrice * priceMultiplyer,
          testCase.strikePriceSBT * priceMultiplyer,
          maturity,
          priceUnit
        );
        assert(isValidLBT, "This Bond should be valid");
      });
      it("Invalid LBT for bond order", async function () {
        const testCase = data.validCases[i];
        const bondIDs = await setBond.registerBondGroupForRBM(
          testCase,
          maturity.toNumber(),
          bondMakerInstance,
          generatorInstance,
          undefined
        );
        await bondMakerInstance.registerNewBondGroup(
          [bondIDs.SBTID, bondIDs.Lev2ID, bondIDs.VolSID, bondIDs.CallID],
          maturity
        );

        const isValidLBT = await strategyInstance.isValidLBT(
          bondMakerInstance.address,
          3,
          testCase.ethPrice * priceMultiplyer,
          testCase.strikePriceSBT * priceMultiplyer,
          maturity,
          priceUnit
        );
        assert(!isValidLBT, "This Bond should be invalid");
      });
    }
    for (let i = 0; i < 2; i++) {
      it("should not register invalid shape LBT", async function () {
        const testCase = data.invalidCases[i];
        await setBond.registerBondGroupForRBM(
          testCase,
          maturity.toNumber(),
          bondMakerInstance,
          generatorInstance,
          undefined
        );

        const isValidLBT = await strategyInstance.isValidLBT(
          bondMakerInstance.address,
          2,
          testCase.ethPrice * priceMultiplyer,
          testCase.strikePriceSBT * priceMultiplyer,
          maturity,
          priceUnit
        );
        assert(!isValidLBT, "This Bond should be invalid");
      });
    }
  });

  describe("getTrancheBonds", function () {
    let mockAggregator;
    beforeEach(async function () {
      mockAggregator = await MockAggregator.new();
      volOracleInstance = await VolOracle.new();
      strategyInstance = await Strategy.new(
        exchangeInstance.address,
        608000,
        144000
      );
    });
    for (let i = 0; i < data.TrancheBonds.length; i++) {
      it("return valid order for tranching bond", async function () {
        await setBond.registerTrancheBondsForRBM(
          data.TrancheBonds[i],
          maturity,
          bondMakerInstance,
          oracleInstance,
          mockAggregator,
          accounts,
          generatorInstance,
          false
        );

        const list = await strategyInstance.getTrancheBonds(
          bondMakerInstance.address,
          mockAggregator.address,
          data.TrancheBonds[i].ethPrice * priceMultiplyer,
          data.TrancheBonds[i].bondGroups_bm,
          priceUnit
        );
        for (let j = 1; j < list.length / 2; j++) {
          const correctAmount = data.TrancheBonds[i].returnedAmounts[j * 2 + 2];
          if (correctAmount > 0) {
            assert.equal(
              list[j * 2 + 2].toNumber() < correctAmount * 1.03 &&
                list[j * 2 + 2].toNumber() > correctAmount * 0.97,
              true,
              "Invalid Value Expected: " +
                correctAmount +
                " Actual: " +
                list[j * 2 + 2].toString()
            );
          } else if (correctAmount < 0) {
            assert.equal(
              list[j * 2 + 2].toNumber() > correctAmount * 1.03 &&
                list[j * 2 + 2].toNumber() < correctAmount * 0.97,
              true,
              "Invalid Value Expected: " +
                correctAmount +
                " Actual: " +
                list[j * 2 + 2].toString()
            );
          }
        }
      });
    }
  });

  describe("Tranche Bond", function () {
    let receipt;
    beforeEach(async function () {
      volOracleInstance = await VolOracle.new();
      await aggregatorInstance.addLiquidity({
        value: data.TrancheBonds[0].baseAmount * 10 ** 10,
      });
      await aggregatorInstance.renewMaturity();

      const SBTID = await setBond.registerTrancheBondsForRBM(
        data.TrancheBonds[0],
        maturity,
        bondMakerInstance,
        oracleInstance,
        aggregatorInstance,
        accounts,
        generatorInstance,
        true
      );

      const BGInfo = await bondMakerInstance.getBondGroup(3);
      const bondInfo = await bondMakerInstance.getBond(BGInfo[0][1]);
      const bondToken = await BT.at(bondInfo[0]);
      const balance = await bondToken.balanceOf(aggregatorInstance.address);
      assert.equal(
        balance.toString(),
        "998",
        "Invalid tranche amount returned: " + balance.toString()
      );

      receipt = await aggregatorInstance.trancheBonds();
    });
    it("check first Bond group", async function () {
      const BGInfo = await bondMakerInstance.getBondGroup(2);
      const bondInfo = await bondMakerInstance.getBond(BGInfo[0][1]);
      const bondToken = await BT.at(bondInfo[0]);
      const balance = await bondToken.balanceOf(aggregatorInstance.address);
      assert.equal(
        balance.toString(),
        "199",
        "Invalid tranche amount returned: " + balance.toString()
      );
    });

    it("check second Bond group", async function () {
      const BGInfo = await bondMakerInstance.getBondGroup(3);
      const bondInfo = await bondMakerInstance.getBond(BGInfo[0][1]);
      const bondToken = await BT.at(bondInfo[0]);
      const balance = await bondToken.balanceOf(aggregatorInstance.address);

      assert.equal(
        balance.toString(),
        "0",
        "Invalid tranche amount returned: " + balance.toString()
      );
    });
  });
});

contract("Combine test with unittest", function (accounts) {
  const termInterval = 608000; // 1 week in sec
  const aggregatorLength = termInterval * 3 - 3600 * 12;
  const termCorrectionFactor = 144000; // Friday 16:00 UTC
  const aggregatorType = "Normal LBT";
  const priceUnit = 1000;
  const lot = 10 ** 6;
  let aggregatorInstance;
  let exchangeInstance;
  let volOracleInstance;
  let oracleInstance;
  let pricerInstance;
  let bondMakerInstance;
  let strategyInstance;
  let maturity;
  let strikePrice;
  let BTNameInstance;
  let BTFactoryInstance;
  let generatorInstance;

  beforeEach(async () => {
    volOracleInstance = await VolOracle.new();
    exchangeInstance = await Exchange.new();
    oracleInstance = await Oracle.new();
    pricerInstance = await Pricer.new();
    BTFactoryInstance = await BTFactory.new();
    BTNameInstance = await BTName.new();
    collateralInstance = await testBT.new();
    await collateralInstance.changeDecimal(8);
    await collateralInstance.mint(accounts[0], lot * 10);

    await oracleInstance.changePriceAndVolatility(
      0.0025 * 10 ** 8,
      80 * 10 ** 6
    );

    bondMakerInstance = await BondMakerERC20.new(
      collateralInstance.address,
      oracleInstance.address,
      accounts[0],
      BTNameInstance.address,
      BTFactoryInstance.address,
      1,
      8,
      8
    );
    strategyInstance = await Strategy.new(
      exchangeInstance.address,
      608000,
      144000
    );
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
    generatorInstance = await Generator.new();
    maturity = await strategyInstance.calcNextMaturity();
    const oracleData = await oracleInstance.getData();
    strikePrice = await strategyInstance.getCurrentStrikePrice(
      maturity,
      oracleData[0].toString(),
      oracleData[1].toString(),
      priceUnit
    );
    await collateralInstance.approve(aggregatorInstance.address, lot * 10);

    await collateralInstance.approve(bondMakerInstance.address, lot * 10);
  });
  /*
  describe("isValidLBT", function () {
    for (let i = 0; i < 2; i++) {
      it("valid LBT", async function () {
        const testCase = data.validCasesERC20[i];
        await setBond.registerBondGroupForRBM(
          testCase,
          maturity.toNumber(),
          bondMakerInstance,
          generatorInstance,
          undefined
        );
        const isValidLBT = await strategyInstance.isValidLBT(
          bondMakerInstance.address,
          2,
          testCase.ethPrice * priceMultiplyer,
          testCase.strikePriceSBT * priceMultiplyer,
          maturity,
          priceUnit
        );
        assert(isValidLBT, "This Bond should be valid");
      });
      it("Invalid LBT for bond order", async function () {
        const testCase = data.validCasesERC20[i];
        const bondIDs = await setBond.registerBondGroupForRBM(
          testCase,
          maturity.toNumber(),
          bondMakerInstance,
          generatorInstance,
          undefined
        );
        await bondMakerInstance.registerNewBondGroup(
          [bondIDs.SBTID, bondIDs.Lev2ID, bondIDs.VolSID, bondIDs.CallID],
          maturity
        );

        const isValidLBT = await strategyInstance.isValidLBT(
          bondMakerInstance.address,
          3,
          testCase.ethPrice * priceMultiplyer,
          testCase.strikePriceSBT * priceMultiplyer,
          maturity,
          priceUnit
        );
        assert(!isValidLBT, "This Bond should be invalid");
      });
    }
    for (let i = 0; i < 1; i++) {
      it("should not register invalid shape LBT", async function () {
        const testCase = data.invalidCasesERC20[i];
        await setBond.registerBondGroupForRBM(
          testCase,
          maturity.toNumber(),
          bondMakerInstance,
          generatorInstance,
          undefined
        );

        const isValidLBT = await strategyInstance.isValidLBT(
          bondMakerInstance.address,
          2,
          testCase.ethPrice * priceMultiplyer,
          testCase.strikePriceSBT * priceMultiplyer,
          maturity,
          priceUnit
        );
        assert(!isValidLBT, "This Bond should be invalid");
      });
    }
  });
  */
  describe("getTrancheBonds", function () {
    let mockAggregator;
    beforeEach(async function () {
      mockAggregator = await MockAggregator.new();
      volOracleInstance = await VolOracle.new();
      strategyInstance = await Strategy.new(
        exchangeInstance.address,
        608000,
        144000
      );
    });
    for (let i = 0; i < data.TrancheBondsERC20.length; i++) {
      it("return valid order for tranching bond", async function () {
        await setBond.registerTrancheBondsERC20(
          data.TrancheBondsERC20[i],
          maturity,
          bondMakerInstance,
          oracleInstance,
          mockAggregator,
          accounts,
          generatorInstance,
          collateralInstance,
          8,
          false
        );

        const list = await strategyInstance.getTrancheBonds(
          bondMakerInstance.address,
          mockAggregator.address,
          data.TrancheBondsERC20[i].ethPrice * priceMultiplyer,
          data.TrancheBondsERC20[i].bondGroups_bm,
          priceUnit
        );
        for (let j = 1; j < list.length / 2; j++) {
          const correctAmount =
            data.TrancheBondsERC20[i].returnedAmounts[j * 2 + 2];
          if (correctAmount > 0) {
            assert.equal(
              list[j * 2 + 2].toNumber() < correctAmount * 1.03 &&
                list[j * 2 + 2].toNumber() > correctAmount * 0.97,
              true,
              "Invalid Value Expected: " +
                correctAmount +
                " Actual: " +
                list[j * 2 + 2].toString()
            );
          } else if (correctAmount < 0) {
            assert.equal(
              list[j * 2 + 2].toNumber() > correctAmount * 1.03 &&
                list[j * 2 + 2].toNumber() < correctAmount * 0.97,
              true,
              "Invalid Value Expected: " +
                correctAmount +
                " Actual: " +
                list[j * 2 + 2].toString()
            );
          }
        }
      });
    }
  });
  /*
  describe("Tranche Bond", function () {
    let receipt;
    beforeEach(async function () {
      volOracleInstance = await VolOracle.new();
      await aggregatorInstance.addLiquidity({
        value: data.TrancheBonds[0].baseAmount * 10 ** 10,
      });
      await aggregatorInstance.renewMaturity();

      const SBTID = await setBond.registerTrancheBondsForRBM(
        data.TrancheBonds[0],
        maturity,
        bondMakerInstance,
        oracleInstance,
        aggregatorInstance,
        accounts,
        generatorInstance,
        true
      );

      const BGInfo = await bondMakerInstance.getBondGroup(3);
      const bondInfo = await bondMakerInstance.getBond(BGInfo[0][1]);
      const bondToken = await BT.at(bondInfo[0]);
      const balance = await bondToken.balanceOf(aggregatorInstance.address);
      assert.equal(
        balance.toString(),
        "998",
        "Invalid tranche amount returned: " + balance.toString()
      );

      receipt = await aggregatorInstance.trancheBonds();
    });
    it("check first Bond group", async function () {
      const BGInfo = await bondMakerInstance.getBondGroup(2);
      const bondInfo = await bondMakerInstance.getBond(BGInfo[0][1]);
      const bondToken = await BT.at(bondInfo[0]);
      const balance = await bondToken.balanceOf(aggregatorInstance.address);
      assert.equal(
        balance.toString(),
        "199",
        "Invalid tranche amount returned: " + balance.toString()
      );
    });

    it("check second Bond group", async function () {
      const BGInfo = await bondMakerInstance.getBondGroup(3);
      const bondInfo = await bondMakerInstance.getBond(BGInfo[0][1]);
      const bondToken = await BT.at(bondInfo[0]);
      const balance = await bondToken.balanceOf(aggregatorInstance.address);

      assert.equal(
        balance.toString(),
        "0",
        "Invalid tranche amount returned: " + balance.toString()
      );
    });
  });
  */
});
