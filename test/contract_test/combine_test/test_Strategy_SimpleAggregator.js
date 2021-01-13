const ZAddress = "0x0000000000000000000000000000000000000000";
const BondMaker = artifacts.require("TestBondMaker");
const BondMakerERC20 = artifacts.require("TestERC20BondMaker");
const Aggregator = artifacts.require("testSimpleAggregatorCollateralizedEth");
const AggregatorERC20 = artifacts.require(
  "testSimpleAggregatorCollateralizedERC20"
);

const BT = artifacts.require("testBondToken");

const Strategy = artifacts.require("StrategyForSimpleAggregator");
const Exchange = artifacts.require("TestExchange");
const VolOracle = artifacts.require("testVolatilityOracle");
const Oracle = artifacts.require("testOracleForAggregator");
const Pricer = artifacts.require("testGeneralizedPricing");
const { time, expectRevert } = require("@openzeppelin/test-helpers");
let setBond = require("../../utils/setBond.js");
const fs = require("fs");

contract("with Strategy", function (accounts) {
  const priceUnit = 1000000000;
  const termInterval = 608000; // 1 week in sec
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
  beforeEach(async () => {
    volOracleInstance = await VolOracle.new();
    exchangeInstance = await Exchange.new();
    bondMakerInstance = await BondMaker.new();
    oracleInstance = await Oracle.new();
    pricerInstance = await Pricer.new();

    strategyInstance = await Strategy.new(
      exchangeInstance.address,
      608000,
      144000
    );
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

  describe("Aggregator-Strategy", function () {
    const inputFile = "test/contract_test/unit_test/Strategy/testCases.json";
    const data = JSON.parse(fs.readFileSync(inputFile, "utf8"));

    describe("Add Valid bond group", function () {
      for (let i = 0; i < data.validCases.length; i++) {
        beforeEach(async () => {
          await aggregatorInstance.updateBondGroupData();
        });
        it("register valid LBT", async function () {
          const testCase = data.validCases[i];
          const fnMaps = await setBond.registerBondGroup(
            testCase,
            maturity,
            bondMakerInstance
          );
          await bondMakerInstance.registerBondPair2(
            maturity,
            data.validCases[i].strikePriceSBT * 10 ** 8,
            [
              fnMaps.SBTFnMapID,
              fnMaps.LBTFnMapID,
              fnMaps.VolSFnMapID,
              fnMaps.Lev2FnMapID,
            ]
          );
          let bondIndex = await bondMakerInstance.getBondIndex();
          console.log("bond index: " + bondIndex.toString());
          await time.increaseTo(maturity.toNumber() - 100000);
          await aggregatorInstance.addIssuableBondGroup(2);
        });

        it("cannot register invalid LBT", async function () {
          const testCase = data.validCases[i];
          const fnMaps = await setBond.registerBondGroup(
            testCase,
            maturity.toNumber() + 100000,
            bondMakerInstance
          );
          await bondMakerInstance.registerBondPair2(
            maturity.toNumber() + 100000,
            data.validCases[i].strikePriceSBT * 10 ** 8,
            [
              fnMaps.SBTFnMapID,
              fnMaps.LBTFnMapID,
              fnMaps.VolSFnMapID,
              fnMaps.Lev2FnMapID,
            ]
          );
          await time.increaseTo(maturity.toNumber() - 100000);
          await expectRevert.unspecified(
            aggregatorInstance.addIssuableBondGroup(2)
          );
        });
      }

      for (let i = 0; i < data.invalidCases.length; i++) {
        it("should not register invalid shape LBT", async function () {
          const testCase = data.invalidCases[i];
          const fnMaps = await setBond.registerBondGroup(
            testCase,
            maturity,
            bondMakerInstance
          );
          await bondMakerInstance.registerBondPair2(
            maturity,
            data.invalidCases[i].strikePriceSBT * 10 ** 8,
            [
              fnMaps.SBTFnMapID,
              fnMaps.LBTFnMapID,
              fnMaps.VolSFnMapID,
              fnMaps.Lev2FnMapID,
            ]
          );
          await time.increaseTo(maturity.toNumber() - 100000);
          await expectRevert.unspecified(
            aggregatorInstance.addIssuableBondGroup(2)
          );
        });
      }
    });

    describe("Tranche Bond", function () {
      for (let i = 0; i < 6; i++) {
        it("should tranche Bond", async function () {
          await bondMakerInstance.sendTransaction({
            from: accounts[0],
            value: web3.utils.toWei("2", "ether"),
          });
          await setBond.registerTrancheBonds(
            data.TrancheBonds[i],
            maturity,
            bondMakerInstance,
            oracleInstance,
            aggregatorInstance,
            true
          );
          let bondIndex = await bondMakerInstance.getBondIndex();
          console.log("bond index: " + bondIndex.toString());

          await aggregatorInstance.addLiquidity({
            value: data.TrancheBonds[i].baseAmount * 10 ** 10,
          });
          await aggregatorInstance.renewMaturity();
          await aggregatorInstance.addIssuableBondGroups(
            data.TrancheBonds[i].bondGroups
          );

          const receipt = await aggregatorInstance.trancheBonds();
          let j = 0;
          const balanceOfExchange = await web3.eth.getBalance(
            exchangeInstance.address
          );

          assert.equal(
            String(balanceOfExchange),
            String(data.TrancheBonds[i].baseAmount * 10 ** 9),
            "Invalid amount of ethAllowance expected: " +
              String(data.TrancheBonds[i].returnedAmounts[0]) +
              " returned: " +
              String(balanceOfExchange)
          );
          for (
            let logIndex = 1;
            logIndex < data.TrancheBonds[i].returnedAmounts.length + 1 / 2;
            logIndex++
          ) {
            if (
              Number(data.TrancheBonds[i].returnedAmounts[logIndex * 2]) < 0
            ) {
              assert.equal(
                receipt.logs[j].args.to,
                ZAddress,
                "this event should be burn event"
              );
              assert.equal(
                receipt.logs[j].args.value.toString(),
                String(
                  Number(data.TrancheBonds[i].returnedAmounts[logIndex * 2]) *
                    -1
                ),
                "Invalid Value Expected: " +
                  String(
                    Number(data.TrancheBonds[i].returnedAmounts[logIndex * 2]) *
                      -1
                  ) +
                  " Actual: " +
                  receipt.logs[j].args.value.toString()
              );
              if (i == 3 || i == 5) {
                j = j + 6;
              } else {
                j = j + 3;
              }
            } else if (
              Number(data.TrancheBonds[i].returnedAmounts[logIndex * 2]) > 0
            ) {
              assert.equal(
                receipt.logs[j].args.value.toString(),
                data.TrancheBonds[i].returnedAmounts[logIndex * 2],
                "Invalid Value Expected: " +
                  data.TrancheBonds[i].returnedAmounts[logIndex * 2] +
                  " Actual: " +
                  receipt.logs[j].args.value.toString()
              );
              assert.equal(
                receipt.logs[j + 1].args.from,
                ZAddress,
                "this event should be mint event"
              );
              j = j + 4;
            }
          }
        });
      }
    });
  });
});

contract("with Strategy ERC20", function (accounts) {
  const termInterval = 608000; // 1 week in sec
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
  const priceUnit = 1000;
  const lot = 10 ** 6;
  beforeEach(async () => {
    volOracleInstance = await VolOracle.new();
    exchangeInstance = await Exchange.new();
    oracleInstance = await Oracle.new();
    pricerInstance = await Pricer.new();
    collateralInstance = await BT.new();
    await collateralInstance.changeDecimal(8);
    await collateralInstance.mint(accounts[0], lot * 10);

    await oracleInstance.changePriceAndVolatility(
      0.0025 * 10 ** 8,
      80 * 10 ** 6
    );

    strategyInstance = await Strategy.new(
      exchangeInstance.address,
      608000,
      144000
    );
    bondMakerInstance = await BondMakerERC20.new(collateralInstance.address);
    maturity = await strategyInstance.calcNextMaturity();
    const oracleData = await oracleInstance.getData();
    strikePrice = await strategyInstance.getCurrentStrikePrice(
      maturity,
      oracleData[0].toString(),
      oracleData[1].toString(),
      priceUnit
    );
    //console.log(strikePrice.toString());
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
    await collateralInstance.approve(aggregatorInstance.address, lot * 10);

    await collateralInstance.approve(bondMakerInstance.address, lot * 10);
  });

  describe("Aggregator-Strategy", function () {
    const inputFile = "test/contract_test/unit_test/Strategy/testCases.json";
    const data = JSON.parse(fs.readFileSync(inputFile, "utf8"));

    describe("Add Valid bond group", function () {
      for (let i = 0; i < 1; i++) {
        beforeEach(async () => {
          await aggregatorInstance.updateBondGroupData();
        });
        it("register valid LBT", async function () {
          const testCase = data.validCasesERC20[i];
          const fnMaps = await setBond.registerBondGroup(
            testCase,
            maturity,
            bondMakerInstance
          );
          await bondMakerInstance.registerBondPair2(
            maturity,
            data.validCasesERC20[i].strikePriceSBT * 10 ** 8,
            [
              fnMaps.SBTFnMapID,
              fnMaps.LBTFnMapID,
              fnMaps.VolSFnMapID,
              fnMaps.Lev2FnMapID,
            ]
          );
          const BGInfo = await bondMakerInstance.getBondGroup(1);
          const bondInfo = await bondMakerInstance.getBond(BGInfo[0][0]);
          console.log(bondInfo[2].toString());
          let bondIndex = await bondMakerInstance.getBondIndex();
          //console.log("bond index: " + bondIndex.toString());
          await time.increaseTo(maturity.toNumber() - 100000);
          await aggregatorInstance.addIssuableBondGroup(2);
        });

        it("cannot register invalid LBT", async function () {
          const testCase = data.validCasesERC20[i];
          const fnMaps = await setBond.registerBondGroup(
            testCase,
            maturity.toNumber() + 100000,
            bondMakerInstance
          );
          await bondMakerInstance.registerBondPair2(
            maturity.toNumber() + 100000,
            data.validCasesERC20[i].strikePriceSBT * 10 ** 8,
            [
              fnMaps.SBTFnMapID,
              fnMaps.LBTFnMapID,
              fnMaps.VolSFnMapID,
              fnMaps.Lev2FnMapID,
            ]
          );
          await time.increaseTo(maturity.toNumber() - 100000);
          await expectRevert.unspecified(
            aggregatorInstance.addIssuableBondGroup(2)
          );
        });
      }

      for (let i = 0; i < 1; i++) {
        it("should not register invalid shape LBT", async function () {
          const testCase = data.invalidCases[i];
          const fnMaps = await setBond.registerBondGroup(
            testCase,
            maturity,
            bondMakerInstance
          );
          await bondMakerInstance.registerBondPair2(
            maturity,
            data.invalidCases[i].strikePriceSBT * 10 ** 8,
            [
              fnMaps.SBTFnMapID,
              fnMaps.LBTFnMapID,
              fnMaps.VolSFnMapID,
              fnMaps.Lev2FnMapID,
            ]
          );
          await time.increaseTo(maturity.toNumber() - 100000);
          await expectRevert.unspecified(
            aggregatorInstance.addIssuableBondGroup(2)
          );
        });
      }
    });

    describe("Tranche Bond", function () {
      for (let i = 0; i < 1; i++) {
        it("should tranche Bond", async function () {
          /*await collateralInstance.transfer({
            from: accounts[0],
            value: web3.utils.toWei("2", "ether"),
          });
          */
          await collateralInstance.mint(bondMakerInstance.address, lot * 10);
          await setBond.registerTrancheBonds(
            data.TrancheBondsERC20[i],
            maturity,
            bondMakerInstance,
            oracleInstance,
            aggregatorInstance,
            true
          );
          let bondIndex = await bondMakerInstance.getBondIndex();
          console.log("bond index: " + bondIndex.toString());

          await aggregatorInstance.addLiquidity(
            data.TrancheBondsERC20[i].baseAmount
          );
          await aggregatorInstance.renewMaturity();
          await aggregatorInstance.addIssuableBondGroups(
            data.TrancheBondsERC20[i].bondGroups
          );
          const oracleData = await oracleInstance.getData();
          /*
          const list = await strategyInstance.getTrancheBonds(
            bondMakerInstance,
            aggregatorInstance.address,
            oracleData[0].toString(),
            data.TrancheBondsERC20[i].bondGroups,
            priceUnit
          );
          console.log(list);
          */

          const receipt = await aggregatorInstance.trancheBonds();
          let j = 3;
          console.log(receipt.logs);

          for (
            let logIndex = 1;
            logIndex < data.TrancheBondsERC20[i].returnedAmounts.length + 1 / 2;
            logIndex++
          ) {
            if (
              Number(data.TrancheBondsERC20[i].returnedAmounts[logIndex * 2]) <
              0
            ) {
              assert.equal(
                receipt.logs[j].args.to,
                ZAddress,
                "this event should be burn event"
              );
              assert.equal(
                receipt.logs[j].args.value.toString(),
                String(
                  Number(
                    data.TrancheBondsERC20[i].returnedAmounts[logIndex * 2]
                  ) * -1
                ),
                "Invalid Value Expected: " +
                  String(
                    Number(
                      data.TrancheBondsERC20[i].returnedAmounts[logIndex * 2]
                    ) * -1
                  ) +
                  " Actual: " +
                  receipt.logs[j].args.value.toString()
              );
              /*if (i == 3 || i == 5) {
                j = j + 6;
              } else {*/
              j = j + 1;
              //}
            } else if (
              Number(data.TrancheBondsERC20[i].returnedAmounts[logIndex * 2]) >
              0
            ) {
              assert.equal(
                receipt.logs[j].args.value.toString(),
                data.TrancheBondsERC20[i].returnedAmounts[logIndex * 2],
                "Invalid Value Expected: " +
                  data.TrancheBondsERC20[i].returnedAmounts[logIndex * 2] +
                  " Actual: " +
                  receipt.logs[j].args.value.toString()
              );
              assert.equal(
                receipt.logs[j].args.from,
                ZAddress,
                "this event should be mint event"
              );
              j = j + 9;
            }
          }
        });
      }
    });
  });
});
