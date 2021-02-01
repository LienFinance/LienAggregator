const ZAddress = "0x0000000000000000000000000000000000000000";
const ZBytes32 =
  "0x0000000000000000000000000000000000000000000000000000000000000000";
const Aggregator = artifacts.require("testSimpleAggregatorCollateralizedEth");
const AggregatorERC20 = artifacts.require(
  "testSimpleAggregatorCollateralizedERC20"
);
const BigNumber = require("bignumber.js");
const Registrator = artifacts.require("testBondRegistrator");
const Detector = artifacts.require("DetectBondShape");
const BondMaker = artifacts.require("BondMakerCollateralizedEth");
const BondMakerERC20 = artifacts.require("BondMakerCollateralizedErc20");
const Strategy = artifacts.require("StrategyForSimpleAggregator");
const StrategyETH = artifacts.require("StrategyForSimpleAggregatorETH");
const MockAggregator = artifacts.require("MockSimpleAggregator");
const MochBM = artifacts.require("TestBondMaker");
const Exchange = artifacts.require("GeneralizedDotc");
const Oracle = artifacts.require("testOracleForAggregator");
const GeneralizedPricing = artifacts.require("GeneralizedPricing");
const Pricer = artifacts.require("BondPricerWithAcceptableMaturity");
const Generator = artifacts.require("fnMapGenerator");
const BT = artifacts.require("BondToken");
const testBT = artifacts.require("testBondToken");
const BTFactory = artifacts.require("BondTokenFactory");
const BTName = artifacts.require("BondTokenName");
const VolOracle = artifacts.require("testVolatilityOracle");
const { time, expectRevert } = require("@openzeppelin/test-helpers");
let setBond = require("../../utils/setBond.js");
const constants = require("../../utils/constants.js");
const fs = require("fs");
const inputFile = "test/contract_test/unit_test/Strategy/testCases.json";
const data = JSON.parse(fs.readFileSync(inputFile, "utf8"));
const priceMultiplyer = 10 ** 8;

contract("Combine test: BondMaker-ETHAggregator", function (accounts) {
  const termInterval = 604800; // 1 week in sec
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
  let rewardInstance;
  let registratorInstance;
  beforeEach(async () => {
    volOracleInstance = await VolOracle.new();
    oracleInstance = await Oracle.new();
    const generalizedPricer = await GeneralizedPricing.new();
    pricerInstance = await Pricer.new(generalizedPricer.address);
    BTFactoryInstance = await BTFactory.new();
    BTNameInstance = await BTName.new();
    bondMakerInstance = await BondMaker.new(
      oracleInstance.address,
      accounts[0],
      BTNameInstance.address,
      BTFactoryInstance.address,
      1
    );
    const detectorInstance = await Detector.new();
    exchangeInstance = await Exchange.new(
      bondMakerInstance.address,
      volOracleInstance.address,
      oracleInstance.address,
      detectorInstance.address
    );
    strategyInstance = await StrategyETH.new(
      exchangeInstance.address,
      604800,
      144000
    );
    registratorInstance = await Registrator.new();
    rewardInstance = await testBT.new();
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
    await strategyInstance.registerAggregators(
      oracleInstance.address,
      false,
      [aggregatorInstance.address],
      100,
      50
    );
    await pricerInstance.transferOwnership(aggregatorInstance.address);
    generatorInstance = await Generator.new();
    maturity = await strategyInstance.calcNextMaturity();
    const oracleData = await oracleInstance.getData();
    strikePrice = await strategyInstance.getCurrentStrikePrice(
      oracleData[0].toString(),
      priceUnit,
      false
    );
  });

  describe("Register Bond functions", function () {
    let SBTBondID;
    let CallBondID;
    let Lev2BondID;
    let VolShortBondID;
    let maturity;
    beforeEach(async () => {
      maturity = await strategyInstance.calcNextMaturity();
      const mockBM = await MochBM.new();
      let fnMap = await mockBM.generateFnMap(constants.sbtPoint_ETH);
      SBTBondID = await bondMakerInstance.generateBondID(maturity, fnMap);
      fnMap = await mockBM.generateFnMap(constants.callPoint_ETH);
      CallBondID = await bondMakerInstance.generateBondID(maturity, fnMap);
      fnMap = await mockBM.generateFnMap(constants.lev2Point_ETH);
      Lev2BondID = await bondMakerInstance.generateBondID(maturity, fnMap);
      fnMap = await mockBM.generateFnMap(constants.volShortPoint_ETH);
      VolShortBondID = await bondMakerInstance.generateBondID(maturity, fnMap);
    });

    describe("registerBond", function () {
      it("register SBT", async function () {
        const receipt = await registratorInstance._registerBond(
          bondMakerInstance.address,
          constants.sbtPoint_ETH,
          maturity
        );
        assert.equal(receipt.logs[0].args.id, SBTBondID, "Invalid SBT ID");
      });
      it("register Call", async function () {
        const receipt = await registratorInstance._registerBond(
          bondMakerInstance.address,
          constants.callPoint_ETH,
          maturity
        );
        assert.equal(receipt.logs[0].args.id, CallBondID, "Invalid Call ID");
      });
      it("register Lev2", async function () {
        const receipt = await registratorInstance._registerBond(
          bondMakerInstance.address,
          constants.lev2Point_ETH,
          maturity
        );
        assert.equal(receipt.logs[0].args.id, Lev2BondID, "Invalid Lev2 ID");
      });
      it("register VolShort", async function () {
        const receipt = await registratorInstance._registerBond(
          bondMakerInstance.address,
          constants.volShortPoint_ETH,
          maturity
        );
        assert.equal(
          receipt.logs[0].args.id,
          VolShortBondID,
          "Invalid VolShort ID"
        );
      });
    });
    describe("registerSBT", function () {
      let receipt;
      beforeEach(async () => {
        receipt = await registratorInstance._registerSBT(
          bondMakerInstance.address,
          200 * constants.multiplyer,
          maturity
        );
      });
      it("check SBT ID", async function () {
        assert.equal(receipt.logs[0].args.id, SBTBondID, "Invalid SBT ID");
      });
      it("check inf approve", async function () {
        const sbtInfo = await bondMakerInstance.getBond(SBTBondID);
        const sbt = await testBT.at(sbtInfo[0]);
        const bond1Approval = await sbt.allowance(
          aggregatorInstance.address,
          exchangeInstance.address
        );
      });
    });

    describe("registerBondGroup", function () {
      let receipt;
      let bondIDs;
      beforeEach(async () => {
        await aggregatorInstance.updateBondGroupData();
        receipt = await registratorInstance._registerBondGroup(
          bondMakerInstance.address,
          400 * constants.multiplyer,
          200 * constants.multiplyer,
          maturity,
          SBTBondID
        );
        const BGInfo = await bondMakerInstance.getBondGroup(1);
        bondIDs = BGInfo[0];
      });
      it("check bond group ID", async function () {
        assert.equal(
          receipt.logs[0].args.num.toString(),
          "1",
          "Invalid bond group id returned: " +
            receipt.logs[0].args.num.toString()
        );
      });
      it("check Call ID", async function () {
        assert.equal(bondIDs[1], CallBondID, "Invalid Call ID");
      });
      it("check Lev2 ID", async function () {
        assert.equal(bondIDs[2], Lev2BondID, "Invalid lev2 ID");
      });
      it("check Volshort ID", async function () {
        assert.equal(bondIDs[3], VolShortBondID, "Invalid VolShort ID");
      });
    });

    describe("add suitable bond", function () {
      let bondIDs;
      beforeEach(async () => {
        await aggregatorInstance.updateBondGroupData();
        await aggregatorInstance.addSuitableBondGroup(
          400 * constants.multiplyer
        );
        const BGInfo = await bondMakerInstance.getBondGroup(1);
        bondIDs = BGInfo[0];
      });
      it("check Call ID", async function () {
        assert.equal(bondIDs[1], CallBondID, "Invalid Call ID");
      });
      it("check Lev2 ID", async function () {
        assert.equal(bondIDs[2], Lev2BondID, "Invalid lev2 ID");
      });
      it("check Volshort ID", async function () {
        assert.equal(bondIDs[3], VolShortBondID, "Invalid VolShort ID");
      });
      it("check bond group list", async function () {
        const bondGroupID = await aggregatorInstance.getBondGroupIdFromStrikePrice(
          1,
          strikePrice * 2
        );
        assert.equal(
          bondGroupID.toString(),
          "1",
          "bond group id returned: " + bondGroupID.toString()
        );
      });
    });
    describe("update bond group for SBT registration", function () {
      beforeEach(async function () {
        await aggregatorInstance.updateBondGroupData();
      });
      it("check SBT ID", async function () {
        const termInfo = await aggregatorInstance.getTermInfo(1);
        assert.equal(termInfo[2], SBTBondID, "Invalid SBT ID");
      });
    });
  });

  describe("update feebase", () => {
    let maturity;
    beforeEach(async () => {
      maturity = await strategyInstance.calcNextMaturity();
      await aggregatorInstance.addLiquidity({
        value: web3.utils.toWei("1", "ether"),
      });
      await aggregatorInstance.renewMaturity();
    });

    it("check default feebase", async () => {
      const info = await aggregatorInstance.getCurrentStatus();
      assert.equal(
        info[1].toString(),
        "250",
        "Invalid feebase returned: " + info[1].toString()
      );
    });

    it("If eth balance increased", async () => {
      await aggregatorInstance.sendTransaction({
        value: web3.utils.toWei("1", "ether"),
      });

      await time.increaseTo(maturity.toNumber() + 100);
      await aggregatorInstance.liquidateBonds();
      await aggregatorInstance.renewMaturity();
      await aggregatorInstance.changeSpread();
      const info = await aggregatorInstance.getCurrentStatus();
      assert.equal(
        info[1].toString(),
        "250",
        "Invalid feebase returned: " + info[1].toString()
      );
    });

    it("If eth balance decreased", async () => {
      await aggregatorInstance.withdrawCollateral(new BigNumber(5 * 10 ** 17));
      await time.increaseTo(maturity.toNumber() + 100);
      await aggregatorInstance.liquidateBonds();
      await aggregatorInstance.renewMaturity();
      await aggregatorInstance.changeSpread();
      const info = await aggregatorInstance.getCurrentStatus();
      assert.equal(
        info[1].toString(),
        "350",
        "Invalid feebase returned: " + info[1].toString()
      );
    });

    it("If eth balance increased #2", async () => {
      await aggregatorInstance.withdrawCollateral(new BigNumber(5 * 10 ** 17));
      await time.increaseTo(maturity.toNumber() + 100);
      await aggregatorInstance.liquidateBonds();
      await aggregatorInstance.renewMaturity();
      await aggregatorInstance.changeSpread();
      await aggregatorInstance.sendTransaction({
        value: web3.utils.toWei("1", "ether"),
      });
      maturity = await strategyInstance.calcNextMaturity();
      await time.increaseTo(maturity.toNumber() + 100);
      await aggregatorInstance.liquidateBonds();
      await aggregatorInstance.renewMaturity();
      await aggregatorInstance.changeSpread();
      const info = await aggregatorInstance.getCurrentStatus();
      assert.equal(
        info[1].toString(),
        "300",
        "Invalid feebase returned: " + info[1].toString()
      );
    });
  });

  describe("getTrancheBonds", function () {
    let mockAggregator;
    beforeEach(async function () {
      mockAggregator = await MockAggregator.new();
      volOracleInstance = await VolOracle.new();
      strategyInstance = await Strategy.new(604800, 144000);
    });
    for (let i = 0; i < 1; i++) {
      it("return valid order for tranching bond", async function () {
        await setBond.registerTrancheBondsForRBM(
          data.TrancheBonds[i],
          maturity,
          bondMakerInstance,
          oracleInstance,
          mockAggregator,
          accounts,
          generatorInstance,
          false,
          ZAddress
        );

        const ans = await strategyInstance.getTrancheBonds(
          bondMakerInstance.address,
          mockAggregator.address,
          data.TrancheBonds[i].issueBondGroup_bm,
          400 * 10 ** 8,
          data.TrancheBonds[i].bondGroups_bm,
          priceUnit,
          false
        );
        const list = ans[2];
        assert(
          ans[0].toNumber() + 5 > data.TrancheBonds[i].issueAmount &&
            ans[0].toNumber() - 5 < data.TrancheBonds[i].issueAmount,
          "Invalid Amount returned" + ans[0].toString()
        );

        for (let j = 1; j < list.length; j++) {
          const correctAmount = data.TrancheBonds[i].returnedAmounts_bm[j];
          assert(
            list[j].toNumber() + 5 > Number(correctAmount) &&
              list[j].toNumber() - 5 < Number(correctAmount),
            "Invalid Value Expected: " +
              correctAmount +
              " Actual: " +
              list[j].toString()
          );
        }
      });
    }
  });

  describe("Tranche Bond", function () {
    describe("first tranche", function () {
      let bondIDs1;
      beforeEach(async () => {
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
        const bondIndex = await bondMakerInstance.nextBondGroupID();
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
          const bondIndex = await bondMakerInstance.nextBondGroupID();
          assert.equal(
            bondIndex.toString(),
            "3",
            "invalid bond group id returned: " + bondIndex.toString()
          );
        });
        it("check sbt amount", async function () {
          const BondInfo = await bondMakerInstance.getBond(bondIDs1[0]);
          const Bond = await BT.at(BondInfo[0]);
          const amount = await Bond.balanceOf(aggregatorInstance.address);
          assert.equal(
            amount.toString(),
            "179",
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

  describe("TrancheBonds twice", function () {
    it("call twice for insufficient interval", async function () {
      await aggregatorInstance.addLiquidity({
        value: new BigNumber(10 ** 18).toString(),
      });
      await aggregatorInstance.renewMaturity();
      await aggregatorInstance.trancheBonds();
      await expectRevert.unspecified(aggregatorInstance.trancheBonds());
    });
    it("call twice for sufficient interval", async function () {
      await aggregatorInstance.addLiquidity({
        value: new BigNumber(10 ** 18).toString(),
      });
      await aggregatorInstance.renewMaturity();
      await aggregatorInstance.trancheBonds();
      await time.increase(3600 * 24 * 3 + 100);
      const firstBalance = await web3.eth.getBalance(
        aggregatorInstance.address
      );
      await aggregatorInstance.trancheBonds();
      const secondBalance = await web3.eth.getBalance(
        aggregatorInstance.address
      );
    });
  });

  describe("tranche bond and liquidate bonds", function () {
    const inputFile = "test/contract_test/combine_test/testCases.json";
    const data = JSON.parse(fs.readFileSync(inputFile, "utf8"));
    async function getBondInstance(bondMakerInstance, bondNumber) {
      const BondGroupInfo = await bondMakerInstance.getBondGroup(bondNumber[0]);
      const BondInfo = await bondMakerInstance.getBond(
        BondGroupInfo[0][bondNumber[1]]
      );
      return await BT.at(BondInfo[0]);
    }

    async function trancheBonds(aggregatorInstance, oracleInstance, testData) {
      await oracleInstance.changePriceAndVolatility(
        testData.price * 10 ** 8,
        constants.volatility
      );
      await aggregatorInstance.trancheBonds();
    }

    async function exchange(
      aggregatorInstance,
      bondMakerInstance,
      testData,
      accounts
    ) {
      const bondToken = await getBondInstance(
        bondMakerInstance,
        testData.bondNumber
      );
      if (testData.isBuy) {
        await aggregatorInstance.transferBond(
          bondToken.address,
          accounts[0],
          Math.floor(testData.bondAmount * 10 ** 8)
        );
        await aggregatorInstance.sendTransaction({
          from: accounts[0],
          value: web3.utils.toWei(String(testData.collateralAmount), "ether"),
        });
      } else {
        await bondToken.transfer(
          aggregatorInstance.address,
          testData.bondAmount * 10 ** 8
        );
        await aggregatorInstance.withdrawCollateral(
          web3.utils.toWei(String(testData.collateralAmount), "ether")
        );
      }
    }

    async function order(
      order,
      aggregatorInstance,
      bondMakerInstance,
      oracleInstance,
      accounts
    ) {
      if (order.name === "tranche") {
        await trancheBonds(aggregatorInstance, oracleInstance, order);

        await time.increase(3600 * 24 * 3 + 100);
      } else if (order.name === "exchange") {
        await exchange(aggregatorInstance, bondMakerInstance, order, accounts);
      }
    }

    async function orderAll(
      orders,
      aggregatorInstance,
      bondMakerInstance,
      oracleInstance,
      accounts
    ) {
      await order(
        orders[0],
        aggregatorInstance,
        bondMakerInstance,
        oracleInstance,
        accounts
      );
      await order(
        orders[1],
        aggregatorInstance,
        bondMakerInstance,
        oracleInstance,
        accounts
      );
      if (orders.length == 3) {
        await order(
          orders[2],
          aggregatorInstance,
          bondMakerInstance,
          oracleInstance,
          accounts
        );
      }
    }

    async function checkBond(aggregatorInstance, bondMakerInstance, data) {
      const bondToken = await getBondInstance(
        bondMakerInstance,
        data.bondNumber
      );
      const balance = await bondToken.balanceOf(aggregatorInstance.address);
      assert.equal(
        balance.toString(),
        new BigNumber(data.amount)
          .shiftedBy(8)
          //.dividedBy(1.002)
          .toFixed(0, 1)
          .toString(),
        "Invalid bond amount returned. expected: " +
          new BigNumber(data.amount)
            .shiftedBy(8)
            ///.dividedBy(1.002)
            .toFixed(0, 1)
            .toString() +
          "returned: " +
          balance.toString()
      );
    }
    beforeEach(async () => {
      maturity = await strategyInstance.calcNextMaturity();
      const mockBM = await MochBM.new();
      let fnMap = await mockBM.generateFnMap(constants.baseSbtPoint_ETH);
      await bondMakerInstance.registerNewBond(maturity, fnMap);
      const SBTBondID = await bondMakerInstance.generateBondID(maturity, fnMap);
      fnMap = await mockBM.generateFnMap(constants.baseCallPoint_ETH);
      await bondMakerInstance.registerNewBond(maturity, fnMap);
      const CallBondID = await bondMakerInstance.generateBondID(
        maturity,
        fnMap
      );
      await bondMakerInstance.registerNewBondGroup(
        [SBTBondID, CallBondID],
        maturity
      );
      await bondMakerInstance.issueNewBonds(1, {
        value: new BigNumber(10 ** 18).toString(),
      });
      await aggregatorInstance.addLiquidity({
        value: new BigNumber(10 ** 18).toString(),
      });
      await aggregatorInstance.renewMaturity();
    });
    for (let i = 0; i < 7; i++) {
      describe(data.cases[i].title, () => {
        it("check bond value #1", async function () {
          await order(
            data.cases[i].orders[0],
            aggregatorInstance,
            bondMakerInstance,
            oracleInstance,
            accounts
          );
          let checkBondData;
          if (data.cases[i].bondCheck == undefined) {
            checkBondData = data.cases[i].bondCheck_ETH;
          } else {
            checkBondData = data.cases[i].bondCheck;
          }
          await checkBond(
            aggregatorInstance,
            bondMakerInstance,
            checkBondData[0]
          );
        });
        it("check bond value #2", async function () {
          await orderAll(
            data.cases[i].orders,
            aggregatorInstance,
            bondMakerInstance,
            oracleInstance,
            accounts
          );
          let checkBondData;
          if (data.cases[i].bondCheck == undefined) {
            checkBondData = data.cases[i].bondCheck_ETH;
          } else {
            checkBondData = data.cases[i].bondCheck;
          }
          await checkBond(
            aggregatorInstance,
            bondMakerInstance,
            checkBondData[1]
          );
        });
        it("check collateral amount", async function () {
          await orderAll(
            data.cases[i].orders,
            aggregatorInstance,
            bondMakerInstance,
            oracleInstance,
            accounts
          );
          await time.increaseTo(maturity.toNumber() + 100);
          await aggregatorInstance.liquidateBonds();
          await aggregatorInstance.renewMaturity();
          const balance = await web3.eth.getBalance(aggregatorInstance.address);
          assert.equal(
            String(balance),
            new BigNumber(data.cases[i].collateralAmount * 10 ** 18).toString(),
            "Invalid amount returned: " +
              new BigNumber(
                data.cases[i].collateralAmount * 10 ** 18
              ).toString()
          );
        });
        it("check fee base", async function () {
          await orderAll(
            data.cases[i].orders,
            aggregatorInstance,
            bondMakerInstance,
            oracleInstance,
            accounts
          );
          await time.increaseTo(maturity.toNumber() + 100);
          await aggregatorInstance.liquidateBonds();
          await aggregatorInstance.renewMaturity();
          const status = await aggregatorInstance.getCurrentStatus();
          assert.equal(
            status[1].toString(),
            String(data.cases[i].currentFeeBase),
            "Invalid feebase returned: " + status[1].toString()
          );
        });

        it("check CPT", async function () {
          await orderAll(
            data.cases[i].orders,
            aggregatorInstance,
            bondMakerInstance,
            oracleInstance,
            accounts
          );
          await time.increaseTo(maturity.toNumber() + 100);
          await aggregatorInstance.liquidateBonds();
          await aggregatorInstance.renewMaturity();
          const shareData = await aggregatorInstance.totalShareData(2);
          assert.equal(
            shareData[1].toString(),
            String(data.cases[i].CPT_ETH),
            "Invalid Collateral Per Token returned: ",
            shareData[1].toString()
          );
        });
      });
    }
  });
});

contract("Combine test: BondMaker-ERC20Aggregator", function (accounts) {
  const termInterval = 604800; // 1 week in sec
  const aggregatorLength = termInterval * 3 - 3600 * 12;
  const termCorrectionFactor = 144000; // Friday 16:00 UTC
  const aggregatorType = "Normal LBT";
  const priceUnit = 1000000000;
  const lot = new BigNumber(10 ** 8);
  const mintAmount = new BigNumber(10 ** 10);
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
  let rewardInstance;
  let registratorInstance;

  beforeEach(async () => {
    volOracleInstance = await VolOracle.new();
    oracleInstance = await Oracle.new();
    const generalizedPricer = await GeneralizedPricing.new();
    pricerInstance = await Pricer.new(generalizedPricer.address);
    BTFactoryInstance = await BTFactory.new();
    BTNameInstance = await BTName.new();
    collateralInstance = await testBT.new();
    registratorInstance = await Registrator.new();
    rewardInstance = await testBT.new();
    await collateralInstance.changeDecimal(8);
    await collateralInstance.mint(accounts[0], mintAmount);

    await oracleInstance.changePriceAndVolatility(400 * 10 ** 8, 10 * 10 ** 6);

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
    const detectorInstance = await Detector.new();
    exchangeInstance = await Exchange.new(
      bondMakerInstance.address,
      volOracleInstance.address,
      oracleInstance.address,
      detectorInstance.address
    );
    strategyInstance = await StrategyETH.new(
      exchangeInstance.address,
      604800,
      144000
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
    generatorInstance = await Generator.new();
    maturity = await strategyInstance.calcNextMaturity();
    await collateralInstance.approve(aggregatorInstance.address, mintAmount);

    await collateralInstance.approve(bondMakerInstance.address, mintAmount);
  });

  describe("Register Bond functions", function () {
    let SBTBondID;
    let CallBondID;
    let Lev2BondID;
    let VolShortBondID;
    let maturity;
    beforeEach(async () => {
      maturity = await strategyInstance.calcNextMaturity();
      const mockBM = await MochBM.new();
      let fnMap = await mockBM.generateFnMap(constants.sbtPoint_ERC20);
      SBTBondID = await bondMakerInstance.generateBondID(maturity, fnMap);
      fnMap = await mockBM.generateFnMap(constants.callPoint_ERC20);
      CallBondID = await bondMakerInstance.generateBondID(maturity, fnMap);
      fnMap = await mockBM.generateFnMap(constants.lev2Point_ERC20);
      Lev2BondID = await bondMakerInstance.generateBondID(maturity, fnMap);
      fnMap = await mockBM.generateFnMap(constants.volShortPoint_ERC20);
      VolShortBondID = await bondMakerInstance.generateBondID(maturity, fnMap);
    });

    describe("registerBond", function () {
      it("register SBT", async function () {
        const receipt = await registratorInstance._registerBond(
          bondMakerInstance.address,
          constants.sbtPoint_ERC20,
          maturity
        );
        assert.equal(receipt.logs[0].args.id, SBTBondID, "Invalid SBT ID");
      });
      it("register Call", async function () {
        const receipt = await registratorInstance._registerBond(
          bondMakerInstance.address,
          constants.callPoint_ERC20,
          maturity
        );
        assert.equal(receipt.logs[0].args.id, CallBondID, "Invalid Call ID");
      });
      it("register Lev2", async function () {
        const receipt = await registratorInstance._registerBond(
          bondMakerInstance.address,
          constants.lev2Point_ERC20,
          maturity
        );
        assert.equal(receipt.logs[0].args.id, Lev2BondID, "Invalid Lev2 ID");
      });
      it("register VolShort", async function () {
        const receipt = await registratorInstance._registerBond(
          bondMakerInstance.address,
          constants.volShortPoint_ERC20,
          maturity
        );
        assert.equal(
          receipt.logs[0].args.id,
          VolShortBondID,
          "Invalid VolShort ID"
        );
      });
    });
    describe("registerSBT", function () {
      let receipt;
      beforeEach(async () => {
        receipt = await registratorInstance._registerSBT(
          bondMakerInstance.address,
          constants.sbtSp_ERC20,
          maturity
        );
      });
      it("check SBT ID", async function () {
        assert.equal(receipt.logs[0].args.id, SBTBondID, "Invalid SBT ID");
      });
      it("check inf approve", async function () {
        const sbtInfo = await bondMakerInstance.getBond(SBTBondID);
        const sbt = await testBT.at(sbtInfo[0]);
        const bond1Approval = await sbt.allowance(
          aggregatorInstance.address,
          exchangeInstance.address
        );
      });
    });

    describe("registerBondGroup", function () {
      let receipt;
      let bondIDs;
      beforeEach(async () => {
        await aggregatorInstance.updateBondGroupData();
        receipt = await registratorInstance._registerBondGroup(
          bondMakerInstance.address,
          constants.callSp_ERC20,
          constants.sbtSp_ERC20,
          maturity,
          SBTBondID
        );
        const BGInfo = await bondMakerInstance.getBondGroup(1);
        bondIDs = BGInfo[0];
      });
      it("check bond group ID", async function () {
        assert.equal(
          receipt.logs[0].args.num.toString(),
          "1",
          "Invalid bond group id returned: " +
            receipt.logs[0].args.num.toString()
        );
      });
      it("check Call ID", async function () {
        assert.equal(bondIDs[1], CallBondID, "Invalid Call ID");
      });
      it("check Lev2 ID", async function () {
        assert.equal(bondIDs[2], Lev2BondID, "Invalid lev2 ID");
      });
      it("check Volshort ID", async function () {
        assert.equal(bondIDs[3], VolShortBondID, "Invalid VolShort ID");
      });
    });

    describe("add suitable bond", function () {
      let bondIDs;
      beforeEach(async () => {
        await aggregatorInstance.updateBondGroupData();
        await aggregatorInstance.addSuitableBondGroup(400 * 10 ** 8);
        const BGInfo = await bondMakerInstance.getBondGroup(1);
        bondIDs = BGInfo[0];
      });
      it("check Call ID", async function () {
        assert.equal(bondIDs[1], CallBondID, "Invalid Call ID");
      });
      it("check Lev2 ID", async function () {
        assert.equal(bondIDs[2], Lev2BondID, "Invalid lev2 ID");
      });
      it("check Volshort ID", async function () {
        assert.equal(bondIDs[3], VolShortBondID, "Invalid VolShort ID");
      });
      it("check bond group list", async function () {
        const bondGroupID = await aggregatorInstance.getBondGroupIdFromStrikePrice(
          1,
          400 * 10 ** 8
        );
        assert.equal(
          bondGroupID.toString(),
          "1",
          "bond group id returned: " + bondGroupID.toString()
        );
      });
    });

    describe("update bond group for SBT registration", function () {
      beforeEach(async function () {
        await aggregatorInstance.updateBondGroupData();
      });
      it("check SBT ID", async function () {
        const termInfo = await aggregatorInstance.getTermInfo(1);
        assert.equal(termInfo[2], SBTBondID, "Invalid SBT ID");
      });
    });
  });

  describe("update feebase", () => {
    let maturity;
    beforeEach(async () => {
      maturity = await strategyInstance.calcNextMaturity();
      await aggregatorInstance.addLiquidity(lot);
      await aggregatorInstance.renewMaturity();
    });

    it("check default feebase", async () => {
      const info = await aggregatorInstance.getCurrentStatus();
      assert.equal(
        info[1].toString(),
        "250",
        "Invalid feebase returned: " + info[1].toString()
      );
    });

    it("If eth balance increased", async () => {
      await collateralInstance.transfer(aggregatorInstance.address, lot);

      await time.increaseTo(maturity.toNumber() + 100);
      await aggregatorInstance.liquidateBonds();
      await aggregatorInstance.renewMaturity();
      await aggregatorInstance.changeSpread();
      const info = await aggregatorInstance.getCurrentStatus();
      assert.equal(
        info[1].toString(),
        "250",
        "Invalid feebase returned: " + info[1].toString()
      );
    });

    it("If eth balance decreased", async () => {
      await aggregatorInstance.withdrawCollateral(lot.dividedBy(2));
      await time.increaseTo(maturity.toNumber() + 100);
      await aggregatorInstance.liquidateBonds();
      await aggregatorInstance.renewMaturity();
      await aggregatorInstance.changeSpread();
      const info = await aggregatorInstance.getCurrentStatus();
      assert.equal(
        info[1].toString(),
        "350",
        "Invalid feebase returned: " + info[1].toString()
      );
    });

    it("If eth balance increased #2", async () => {
      await aggregatorInstance.withdrawCollateral(lot.dividedBy(2));
      await time.increaseTo(maturity.toNumber() + 100);
      await aggregatorInstance.liquidateBonds();
      await aggregatorInstance.renewMaturity();
      await aggregatorInstance.changeSpread();
      await collateralInstance.transfer(aggregatorInstance.address, lot);
      maturity = await strategyInstance.calcNextMaturity();
      await time.increaseTo(maturity.toNumber() + 100);
      await aggregatorInstance.liquidateBonds();
      await aggregatorInstance.renewMaturity();
      await aggregatorInstance.changeSpread();
      const info = await aggregatorInstance.getCurrentStatus();
      assert.equal(
        info[1].toString(),
        "300",
        "Invalid feebase returned: " + info[1].toString()
      );
    });
  });

  describe("getTrancheBonds", function () {
    let mockAggregator;
    beforeEach(async function () {
      mockAggregator = await MockAggregator.new();
      volOracleInstance = await VolOracle.new();
      strategyInstance = await Strategy.new(604800, 144000);
    });
    for (let i = 0; i < 1; i++) {
      it("return valid order for tranching bond", async function () {
        await setBond.registerTrancheBondsERC20(
          data.TrancheBondsERC20[i],
          maturity,
          bondMakerInstance,
          oracleInstance,
          mockAggregator,
          accounts,
          generatorInstance,
          false,
          collateralInstance,
          8
        );

        const ans = await strategyInstance.getTrancheBonds(
          bondMakerInstance.address,
          mockAggregator.address,
          data.TrancheBondsERC20[i].issueBondGroup,
          400 * 10 ** 8,
          data.TrancheBondsERC20[i].bondGroups_bm,
          priceUnit,
          true
        );
        const list = ans[2];
        assert(
          ans[0].toNumber() + 5 > data.TrancheBondsERC20[i].issueAmount &&
            ans[0].toNumber() - 5 < data.TrancheBondsERC20[i].issueAmount,
          "Invalid Amount returned" + ans[0].toString()
        );

        for (let j = 1; j < list.length; j++) {
          const correctAmount = data.TrancheBondsERC20[i].returnedAmounts_bm[j];
          assert(
            list[j].toNumber() + 5 > Number(correctAmount) &&
              list[j].toNumber() - 5 < Number(correctAmount),
            "Invalid Value Expected: " +
              correctAmount +
              " Actual: " +
              list[j].toString()
          );
        }
      });
    }
  });

  describe("Tranche Bond", function () {
    describe("first tranche", function () {
      let bondIDs1;
      beforeEach(async () => {
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
        const bondIndex = await bondMakerInstance.nextBondGroupID();
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
          "199",
          "Invalid bondAmount returned: " + amount.toString()
        );
      });
      it("check call amount", async function () {
        const BondInfo = await bondMakerInstance.getBond(bondIDs1[1]);
        const Bond = await BT.at(BondInfo[0]);
        const amount = await Bond.balanceOf(aggregatorInstance.address);
        assert.equal(
          amount.toString(),
          "199",
          "Invalid bondAmount returned: " + amount.toString()
        );
      });
      it("check lev2 amount", async function () {
        const BondInfo = await bondMakerInstance.getBond(bondIDs1[2]);
        const Bond = await BT.at(BondInfo[0]);
        const amount = await Bond.balanceOf(aggregatorInstance.address);
        assert.equal(
          amount.toString(),
          "199",
          "Invalid bondAmount returned: " + amount.toString()
        );
      });
      it("check vol short amount", async function () {
        const BondInfo = await bondMakerInstance.getBond(bondIDs1[3]);
        const Bond = await BT.at(BondInfo[0]);
        const amount = await Bond.balanceOf(aggregatorInstance.address);
        assert.equal(
          amount.toString(),
          "199",
          "Invalid bondAmount returned: " + amount.toString()
        );
      });

      describe("second tranche", async function () {
        let bondIDs2;
        beforeEach(async () => {
          await time.increase(3600 * 24 * 3 + 100);
          await oracleInstance.changePriceAndVolatility(
            500 * 10 ** 8,
            10 * 10 ** 6
          );
          await aggregatorInstance.trancheBonds();
          const BG1Info = await bondMakerInstance.getBondGroup(2);
          bondIDs2 = BG1Info[0];
        });
        it("check bond group number", async function () {
          const bondIndex = await bondMakerInstance.nextBondGroupID();
          assert.equal(
            bondIndex.toString(),
            "3",
            "invalid bond group id returned: " + bondIndex.toString()
          );
        });
        it("check sbt amount", async function () {
          const BondInfo = await bondMakerInstance.getBond(bondIDs1[0]);
          const Bond = await BT.at(BondInfo[0]);
          const amount = await Bond.balanceOf(aggregatorInstance.address);
          assert.equal(
            amount.toString(),
            "198",
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
            "198",
            "Invalid bondAmount returned: " + amount.toString()
          );
        });
        it("check first lev2 amount", async function () {
          const BondInfo = await bondMakerInstance.getBond(bondIDs2[2]);
          const Bond = await BT.at(BondInfo[0]);
          const amount = await Bond.balanceOf(aggregatorInstance.address);
          assert.equal(
            amount.toString(),
            "198",
            "Invalid bondAmount returned: " + amount.toString()
          );
        });
        it("check first vol short amount", async function () {
          const BondInfo = await bondMakerInstance.getBond(bondIDs2[3]);
          const Bond = await BT.at(BondInfo[0]);
          const amount = await Bond.balanceOf(aggregatorInstance.address);
          assert.equal(
            amount.toString(),
            "198",
            "Invalid bondAmount returned: " + amount.toString()
          );
        });
      });
    });
  });

  describe("tranche bond and liquidate bonds", function () {
    const volatility = 10 ** 7;
    let maturity;
    const inputFile = "test/contract_test/combine_test/testCases.json";
    const data = JSON.parse(fs.readFileSync(inputFile, "utf8"));
    async function getBondInstance(bondMakerInstance, bondNumber) {
      const BondGroupInfo = await bondMakerInstance.getBondGroup(bondNumber[0]);
      const BondInfo = await bondMakerInstance.getBond(
        BondGroupInfo[0][bondNumber[1]]
      );
      return await BT.at(BondInfo[0]);
    }

    async function trancheBonds(aggregatorInstance, oracleInstance, testData) {
      await oracleInstance.changePriceAndVolatility(
        testData.price * 10 ** 8,
        volatility
      );
      await aggregatorInstance.trancheBonds();
    }

    async function exchange(
      aggregatorInstance,
      collateralInstance,
      bondMakerInstance,
      testData,
      accounts
    ) {
      const bondToken = await getBondInstance(
        bondMakerInstance,
        testData.bondNumber
      );
      if (testData.isBuy) {
        await aggregatorInstance.transferBond(
          bondToken.address,
          accounts[0],
          Math.floor(testData.bondAmount * 10 ** 8)
        );
        await collateralInstance.transfer(
          aggregatorInstance.address,
          Math.floor(testData.collateralAmount * 10 ** 8)
        );
      } else {
        await bondToken.transfer(
          aggregatorInstance.address,
          testData.bondAmount * 10 ** 8
        );
        await aggregatorInstance.withdrawCollateral(
          Math.floor(testData.collateralAmount * 10 ** 8)
        );
      }
    }

    async function order(
      order,
      aggregatorInstance,
      collateralInstance,
      bondMakerInstance,
      oracleInstance,
      accounts
    ) {
      if (order.name === "tranche") {
        await trancheBonds(aggregatorInstance, oracleInstance, order);

        await time.increase(3600 * 24 * 3 + 100);
      } else if (order.name === "exchange") {
        await exchange(
          aggregatorInstance,
          collateralInstance,
          bondMakerInstance,
          order,
          accounts
        );
      }
    }
    async function orderAll(
      orders,
      aggregatorInstance,
      collateralInstance,
      bondMakerInstance,
      oracleInstance,
      accounts
    ) {
      await order(
        orders[0],
        aggregatorInstance,
        collateralInstance,
        bondMakerInstance,
        oracleInstance,
        accounts
      );
      await order(
        orders[1],
        aggregatorInstance,
        collateralInstance,
        bondMakerInstance,
        oracleInstance,
        accounts
      );
      if (orders.length == 3) {
        await order(
          orders[2],
          aggregatorInstance,
          collateralInstance,
          bondMakerInstance,
          oracleInstance,
          accounts
        );
      }
    }

    async function checkBond(aggregatorInstance, bondMakerInstance, data) {
      const bondToken = await getBondInstance(
        bondMakerInstance,
        data.bondNumber
      );
      const balance = await bondToken.balanceOf(aggregatorInstance.address);
      assert.equal(
        balance.toString(),
        new BigNumber(data.amount)
          .shiftedBy(8)
          //.dividedBy(1.002)
          .toFixed(0, 1)
          .toString(),
        "Invalid bond amount returned. expected: " +
          new BigNumber(data.amount)
            .shiftedBy(8)
            ///.dividedBy(1.002)
            .toFixed(0, 1)
            .toString() +
          "returned: " +
          balance.toString()
      );
    }
    beforeEach(async () => {
      maturity = await strategyInstance.calcNextMaturity();
      const mockBM = await MochBM.new();
      let fnMap = await mockBM.generateFnMap(constants.baseSbtPoint_ERC20);
      await bondMakerInstance.registerNewBond(maturity, fnMap);
      const SBTBondID = await bondMakerInstance.generateBondID(maturity, fnMap);
      fnMap = await mockBM.generateFnMap(constants.baseCallPoint_ERC20);
      await bondMakerInstance.registerNewBond(maturity, fnMap);
      const CallBondID = await bondMakerInstance.generateBondID(
        maturity,
        fnMap
      );
      await bondMakerInstance.registerNewBondGroup(
        [SBTBondID, CallBondID],
        maturity
      );
      await bondMakerInstance.issueNewBonds(1, lot);
      await aggregatorInstance.addLiquidity(lot);
      await aggregatorInstance.renewMaturity();
    });
    for (let i = 0; i < 7; i++) {
      describe(data.cases[i].title, () => {
        it("check bond value #1", async function () {
          await order(
            data.cases[i].orders[0],
            aggregatorInstance,
            collateralInstance,
            bondMakerInstance,
            oracleInstance,
            accounts
          );
          let checkBondData;
          if (data.cases[i].bondCheck == undefined) {
            checkBondData = data.cases[i].bondCheck_ERC20;
          } else {
            checkBondData = data.cases[i].bondCheck;
          }
          await checkBond(
            aggregatorInstance,
            bondMakerInstance,
            checkBondData[0]
          );
        });
        it("check bond value #2", async function () {
          await orderAll(
            data.cases[i].orders,
            aggregatorInstance,
            collateralInstance,
            bondMakerInstance,
            oracleInstance,
            accounts
          );
          let checkBondData;
          if (data.cases[i].bondCheck == undefined) {
            checkBondData = data.cases[i].bondCheck_ERC20;
          } else {
            checkBondData = data.cases[i].bondCheck;
          }
          await checkBond(
            aggregatorInstance,
            bondMakerInstance,
            checkBondData[1]
          );
        });
        it("check collateral amount", async function () {
          await orderAll(
            data.cases[i].orders,
            aggregatorInstance,
            collateralInstance,
            bondMakerInstance,
            oracleInstance,
            accounts
          );
          await time.increaseTo(maturity.toNumber() + 100);
          await aggregatorInstance.liquidateBonds();
          await aggregatorInstance.renewMaturity();
          const balance = await collateralInstance.balanceOf(
            aggregatorInstance.address
          );
          assert.equal(
            String(balance),
            new BigNumber(
              data.cases[i].collateralAmountERC20 * 10 ** 8
            ).toFixed(0),
            "Invalid amount returned: " +
              new BigNumber(
                data.cases[i].collateralAmountERC20 * 10 ** 8
              ).toFixed(0)
          );
        });
        it("check fee base", async function () {
          await orderAll(
            data.cases[i].orders,
            aggregatorInstance,
            collateralInstance,
            bondMakerInstance,
            oracleInstance,
            accounts
          );
          await time.increaseTo(maturity.toNumber() + 100);
          await aggregatorInstance.liquidateBonds();
          await aggregatorInstance.renewMaturity();
          const status = await aggregatorInstance.getCurrentStatus();
          assert.equal(
            status[1].toString(),
            String(data.cases[i].currentFeeBase),
            "Invalid feebase returned: " + status[1].toString()
          );
        });
        it("check CPT", async function () {
          await orderAll(
            data.cases[i].orders,
            aggregatorInstance,
            collateralInstance,
            bondMakerInstance,
            oracleInstance,
            accounts
          );
          await time.increaseTo(maturity.toNumber() + 100);
          await aggregatorInstance.liquidateBonds();
          await aggregatorInstance.renewMaturity();
          const shareData = await aggregatorInstance.totalShareData(2);
          assert.equal(
            shareData[1].toString(),
            String(data.cases[i].CPT_ERC20),
            "Invalid Collateral Per Token returned: ",
            shareData[1].toString()
          );
        });
      });
    }
  });
});
