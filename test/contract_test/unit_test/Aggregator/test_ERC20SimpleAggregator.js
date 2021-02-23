const Aggregator = artifacts.require("testSimpleAggregatorCollateralizedERC20");
const BondMaker = artifacts.require("TestERC20BondMaker");
const Reserve = artifacts.require("ReserveERC20");
const Oracle = artifacts.require("testOracleForAggregator");
const Strategy = artifacts.require("MockSimpleStrategy2");
const Exchange = artifacts.require("TestExchange");
const GeneralizedPricing = artifacts.require("GeneralizedPricing");
const Pricer = artifacts.require("BondPricerWithAcceptableMaturity");
const VolOracle = artifacts.require("testVolatilityOracle");
const BT = artifacts.require("testBondToken");
const Registrator = artifacts.require("testBondRegistrator");
const ERC20 = artifacts.require("ERC20");
const BigNumber = require("bignumber.js");
const { time, expectRevert } = require("@openzeppelin/test-helpers");
const lot = 10 ** 8;
const priceUnit = 1000000000;
const strikePrice = 20000000000;
const inf =
  "115792089237316195423570985008687907853269984665640564039457584007913129639935";
const inf_128 = "340282366920938463463374607431768211455";
const fs = require("fs");
const constants = require("../../../utils/constants.js");
const setBonds = require("../../../utils/setBond.js");

contract("simple aggregator", function (accounts) {
  let oracleInstance;
  let pricerInstance;
  let aggregatorInstance;
  let bondMakerInstance;
  let strategyInstance;
  let exchangeInstance;
  let volOracleInstance;
  let reserveERC20Instance;
  let collateralInstance;
  let rewardInstance;
  let registratorInstance;
  beforeEach(async () => {
    volOracleInstance = await VolOracle.new();
    oracleInstance = await Oracle.new();
    const generalizedPricer = await GeneralizedPricing.new();
    pricerInstance = await Pricer.new(generalizedPricer.address);
    collateralInstance = await BT.new();
    registratorInstance = await Registrator.new();
    rewardInstance = await BT.new();
    await collateralInstance.changeDecimal(8);
    await collateralInstance.mint(accounts[0], lot * 10);
    await collateralInstance.mint(accounts[1], lot * 10);

    bondMakerInstance = await BondMaker.new(collateralInstance.address);

    exchangeInstance = await Exchange.new(bondMakerInstance.address);
    strategyInstance = await Strategy.new(bondMakerInstance.address);
    aggregatorInstance = await Aggregator.new(
      oracleInstance.address,
      pricerInstance.address,
      strategyInstance.address,
      rewardInstance.address,
      registratorInstance.address,
      exchangeInstance.address,
      collateralInstance.address,
      volOracleInstance.address,
      priceUnit,
      10 ** 5,
      false
    );
    await pricerInstance.transferOwnership(aggregatorInstance.address);
    reserveERC20Instance = await Reserve.at(
      await aggregatorInstance.getReserveAddress()
    );
    await collateralInstance.approve(aggregatorInstance.address, lot * 10);
    await collateralInstance.approve(aggregatorInstance.address, lot * 10, {
      from: accounts[1],
    });
  });

  describe("Launch contract", function () {
    it("check bond maker contract", async function () {
      const info = await aggregatorInstance.getInfo();
      assert.equal(
        info[0],
        bondMakerInstance.address,
        "Invalid bondmaker Address"
      );
    });
    describe("check default pool", function () {
      it("check erc20 sell pool", async function () {
        const poolID = await exchangeInstance.generateVsErc20PoolID(
          aggregatorInstance.address,
          collateralInstance.address,
          true
        );
        const poolData = await exchangeInstance.getErc20PoolData(poolID);
        assert.equal(
          poolData[0],
          oracleInstance.address,
          "Invalid oracle Address"
        );
        assert.equal(
          poolData[1],
          pricerInstance.address,
          "Invalid pricer Address"
        );
        assert.equal(
          poolData[2],
          collateralInstance.address,
          "Invalid token Address"
        );
        assert.equal(poolData[3], 250, "Invalid feebase");
        assert(poolData[4], "This pool should be sell");
      });

      it("check eth buy pool", async function () {
        const poolID = await exchangeInstance.generateVsErc20PoolID(
          aggregatorInstance.address,
          collateralInstance.address,
          false
        );
        const poolData = await exchangeInstance.getErc20PoolData(poolID);
        assert.equal(
          poolData[0],
          oracleInstance.address,
          "Invalid bondmaker Address"
        );
        assert.equal(
          poolData[1],
          pricerInstance.address,
          "Invalid pricer Address"
        );
        assert.equal(
          poolData[2],
          collateralInstance.address,
          "Invalid token Address"
        );
        assert.equal(poolData[3], 250, "Invalid feebase");
        assert(!poolData[4], "This pool should be buy");
      });
      it("check bond pool", async function () {
        const poolID = await exchangeInstance.generateVsBondPoolID(
          aggregatorInstance.address,
          bondMakerInstance.address
        );
        const poolData = await exchangeInstance.getBondPoolData(poolID);
        assert.equal(
          poolData[0],
          bondMakerInstance.address,
          "Invalid bondmaker Address"
        );
        assert.equal(
          poolData[1],
          pricerInstance.address,
          "Invalid pricer Address"
        );
        assert.equal(
          poolData[2],
          pricerInstance.address,
          "Invalid pricer Address for user"
        );
        assert.equal(poolData[3], 250, "Invalid feebase");
      });
    });

    describe("chenge spread", function () {
      let maturity;
      beforeEach(async () => {
        maturity = await setBonds.calcMaturity();
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
        const poolData = await exchangeInstance.getErc20PoolData(poolID);
        assert.equal(poolData[3], 50, "Invalid feebase");
      });

      it("check erc20 buy pool", async function () {
        const poolID = await exchangeInstance.generateVsErc20PoolID(
          aggregatorInstance.address,
          collateralInstance.address,
          true
        );
        const poolData = await exchangeInstance.getErc20PoolData(poolID);
        assert.equal(poolData[3], 50, "Invalid feebase");
      });
      it("check bond pool", async function () {
        const poolID = await exchangeInstance.generateVsBondPoolID(
          aggregatorInstance.address,
          bondMakerInstance.address
        );
        const poolData = await exchangeInstance.getBondPoolData(poolID);
        assert.equal(
          poolData[0],
          bondMakerInstance.address,
          "Invalid bondmaker Address"
        );
        assert.equal(
          poolData[1],
          pricerInstance.address,
          "Invalid pricer Address"
        );
        assert.equal(
          poolData[2],
          pricerInstance.address,
          "Invalid pricer Address for user"
        );
        assert.equal(poolData[3], 50, "Invalid feebase");
      });
    });
  });

  describe("Register Bond functions", function () {
    let SBTBondID;
    let CallBondID;
    let Lev2BondID;
    let VolShortBondID;
    let maturity;
    beforeEach(async () => {
      const generalizedPricer = await GeneralizedPricing.new();
      pricerInstance = await Pricer.new(generalizedPricer.address);
      aggregatorInstance = await Aggregator.new(
        oracleInstance.address,
        pricerInstance.address,
        strategyInstance.address,
        rewardInstance.address,
        registratorInstance.address,
        exchangeInstance.address,
        collateralInstance.address,
        volOracleInstance.address,
        priceUnit,
        10 ** 5,
        true
      );

      await pricerInstance.transferOwnership(aggregatorInstance.address);
      maturity = await setBonds.calcMaturity();
      SBTBondID = await bondMakerInstance.generateBondIDFromPoint(
        maturity,
        constants.sbtPoint_ERC20
      );
      CallBondID = await bondMakerInstance.generateBondIDFromPoint(
        maturity,
        constants.callPoint_ERC20
      );
      Lev2BondID = await bondMakerInstance.generateBondIDFromPoint(
        maturity,
        constants.lev2Point_ERC20
      );
      VolShortBondID = await bondMakerInstance.generateBondIDFromPoint(
        maturity,
        constants.volShortPoint_ERC20
      );
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
        const sbt = await ERC20.at(sbtInfo[0]);
        const bond1Approval = await sbt.allowance(
          aggregatorInstance.address,
          exchangeInstance.address
        );
        //console.log(bond1Approval.toString());
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

  describe("updateBondGroupData", function () {
    let maturity;
    let receipt;
    let bondIDs;
    let info;
    let termData;
    beforeEach(async () => {
      maturity = await setBonds.calcMaturity();
      receipt = await aggregatorInstance.updateBondGroupData();
      info = await aggregatorInstance.getCurrentStatus();
      termInfo = await aggregatorInstance.getTermInfo(0);
    });
    it("check current term", async () => {
      assert.equal(info[0].toString(), "1", "should increment term");
    });

    it("check maturity", async () => {
      assert.equal(
        termInfo[0].toString(),
        maturity.toString(),
        "invalid maturity"
      );
    });
    it("check strikePrice", async () => {
      assert.equal(
        termInfo[1].toString(),
        strikePrice.toString(),
        "invalid strike price"
      );
    });
    it("check maturity of pricer", async () => {
      const maturityInPricer = await pricerInstance.getAcceptableMaturity();
      assert.equal(
        maturityInPricer.toString(),
        maturity.toString(),
        "invalid maturity"
      );
    });
  });

  describe("add liquidity", () => {
    describe("for the first term", () => {
      beforeEach(async () => {
        await aggregatorInstance.addLiquidity(lot);
      });

      it("check liquidity data", async () => {
        const userData = await aggregatorInstance.getLiquidityReservationData(
          accounts[0]
        );
        assert.equal(userData[0].toString(), "0", "term should be 0");
        assert.equal(
          userData[1].toString(),
          String(lot),
          "Value should be 1 Token"
        );
      });
      it("check total liquidity to add", async () => {
        const total = await aggregatorInstance.getTotalUnmovedAssets();
        assert.equal(
          total[0].toString(),
          String(lot),
          "Total Value should be 1 Token"
        );
      });
    });
    describe("for the second term", () => {
      let maturity;
      beforeEach(async () => {
        maturity = await setBonds.calcMaturity();
        await bondMakerInstance.registerBondPair(maturity, strikePrice);
        await aggregatorInstance.updateBondGroupData();
        await aggregatorInstance.addLiquidity(lot);
      });

      it("check liquidity data", async () => {
        const userData = await aggregatorInstance.getLiquidityReservationData(
          accounts[0]
        );
        assert.equal(userData[0].toString(), "1", "term should be 1");
        assert.equal(
          userData[1].toString(),
          String(lot),
          "Value should be 1 Token"
        );
      });
      it("check total liquidity to add", async () => {
        const total = await aggregatorInstance.getTotalUnmovedAssets();
        assert.equal(
          total[0].toString(),
          String(lot),
          "Total Value should be 1ETH"
        );
      });
    });
  });

  describe("remove liquidity", () => {
    describe("for the first term", () => {
      beforeEach(async () => {
        await aggregatorInstance.addToken(accounts[0], 100000000);
        await aggregatorInstance.removeLiquidity(50000000);
      });

      it("check liquidity data", async () => {
        const userData = await aggregatorInstance.getLiquidityReservationData(
          accounts[0]
        );
        assert.equal(userData[2].toString(), "0", "term should be 0");
        assert.equal(
          userData[3].toString(),
          "50000000",
          "Value should be 0.5 token"
        );
      });
      it("check total liquidity to add", async () => {
        const total = await aggregatorInstance.getTotalUnmovedAssets();
        assert.equal(
          total[1].toString(),
          "50000000",
          "Value should be 0.5 token"
        );
      });
    });
    describe("for the second term", () => {
      let maturity;
      beforeEach(async () => {
        await aggregatorInstance.addToken(accounts[0], 100000000);
        maturity = await setBonds.calcMaturity();
        await bondMakerInstance.registerBondPair(maturity, strikePrice);
        await aggregatorInstance.updateBondGroupData();
        await aggregatorInstance.addLiquidity(lot);
        await aggregatorInstance.removeLiquidity(50000000);
      });

      it("check liquidity data", async () => {
        const userData = await aggregatorInstance.getLiquidityReservationData(
          accounts[0]
        );
        assert.equal(userData[2].toString(), "1", "term should be 1");
        assert.equal(
          userData[3].toString(),
          "50000000",
          "Value should be 0.5 token"
        );
      });
      it("check total liquidity to add", async () => {
        const total = await aggregatorInstance.getTotalUnmovedAssets();
        assert.equal(
          total[1].toString(),
          "50000000",
          "Value should be 0.5 token"
        );
      });
    });
  });
  describe("updatepriceUnits", () => {
    it("update price unit for $ 500", async () => {
      await aggregatorInstance.updatePriceUnit(499 * 10 ** 8);
      const info = await aggregatorInstance.getCurrentStatus();
      assert.equal(
        info[3].toString(),
        "1000000000",
        "price unit should be $10 but returned: " + info[2].toString()
      );
    });
    it("update price unit for $ 600", async () => {
      await aggregatorInstance.updatePriceUnit(600 * 10 ** 8);
      const info = await aggregatorInstance.getCurrentStatus();
      assert.equal(
        info[3].toString(),
        "2500000000",
        "price unit should be $25 but returned: " + info[2].toString()
      );
    });
    it("update price unit for $ 1100", async () => {
      await aggregatorInstance.updatePriceUnit(1100 * 10 ** 8);
      const info = await aggregatorInstance.getCurrentStatus();
      assert.equal(
        info[3].toString(),
        "5000000000",
        "price unit should be $50 but returned: " + info[2].toString()
      );
    });
    it("update price unit for $ 1550", async () => {
      await aggregatorInstance.updatePriceUnit(1550 * 10 ** 8);
      const info = await aggregatorInstance.getCurrentStatus();
      assert.equal(
        info[3].toString(),
        "7500000000",
        "price unit should be $75 but returned: " + info[2].toString()
      );
    });
    it("update price unit for $ 2100", async () => {
      await aggregatorInstance.updatePriceUnit(2100 * 10 ** 8);
      const info = await aggregatorInstance.getCurrentStatus();
      assert.equal(
        info[3].toString(),
        "10000000000",
        "price unit should be $100 but returned: " + info[2].toString()
      );
    });
  });

  describe("addBondGroup", function () {
    let maturity;
    beforeEach(async () => {
      maturity = await setBonds.calcMaturity();
      await aggregatorInstance.updateBondGroupData();
      await bondMakerInstance.registerBondPair(maturity, strikePrice);
      await aggregatorInstance.addBondGroup(2, strikePrice * 2);
    });
    it("check bond group is contained", async () => {
      const bondGroupID = await aggregatorInstance.getBondGroupIdFromStrikePrice(
        1,
        strikePrice * 2
      );
      assert.equal(
        bondGroupID.toString(),
        "2",
        "bond group id returned: " + bondGroupID.toString()
      );
    });

    it("check bond group list length", async () => {
      const bondGroupList = await aggregatorInstance.getIssuableBondGroups();
      assert.equal(
        bondGroupList.length,
        1,
        "invalid bond group list returned: " + bondGroupList
      );
    });

    it("check infinity approve", async function () {
      const bondIDs = await bondMakerInstance.getBondGroup(2);
      const bond1Info = await bondMakerInstance.getBond(bondIDs[0][1]);
      const bond1 = await ERC20.at(bond1Info[0]);
      const bond1Approval = await bond1.allowance(
        aggregatorInstance.address,
        exchangeInstance.address
      );
      assert.equal(bond1Approval.toString(), inf, "Invalid Amount approval");
      const bond2Info = await bondMakerInstance.getBond(bondIDs[0][2]);
      const bond2 = await ERC20.at(bond2Info[0]);
      const bond2Approval = await bond2.allowance(
        aggregatorInstance.address,
        exchangeInstance.address
      );
      assert.equal(bond2Approval.toString(), inf, "Invalid Amount approval");
      const bond3Info = await bondMakerInstance.getBond(bondIDs[0][3]);
      const bond3 = await ERC20.at(bond3Info[0]);
      const bond3Approval = await bond3.allowance(
        aggregatorInstance.address,
        exchangeInstance.address
      );
      assert.equal(bond3Approval.toString(), inf, "Invalid Amount approval");
    });
  });

  describe("getSuitableBondGroup", function () {
    let maturity;
    beforeEach(async () => {
      maturity = await setBonds.calcMaturity();
      await aggregatorInstance.updateBondGroupData();
      await bondMakerInstance.registerBondPair(maturity, strikePrice);
      await aggregatorInstance.addBondGroup(2, strikePrice * 2);
    });
    it("return nearest bond group #1", async function () {
      const bondGroupID = await aggregatorInstance.getSuitableBondGroup(
        strikePrice * 2
      );
      assert.equal(
        bondGroupID.toString(),
        "2",
        "bond group id returned: " + bondGroupID.toString()
      );
    });

    it("return nearest bond group #2", async function () {
      const bondGroupID = await aggregatorInstance.getSuitableBondGroup(
        strikePrice * 2 + 20 * 10 ** 8
      );
      assert.equal(
        bondGroupID.toString(),
        "2",
        "bond group id returned: " + bondGroupID.toString()
      );
    });

    it("return nearest bond group #3", async function () {
      const bondGroupID = await aggregatorInstance.getSuitableBondGroup(
        strikePrice * 2 - 20 * 10 ** 8
      );
      assert.equal(
        bondGroupID.toString(),
        "2",
        "bond group id returned: " + bondGroupID.toString()
      );
    });

    it("return 0 if no near bond group", async function () {
      const bondGroupID = await aggregatorInstance.getSuitableBondGroup(
        strikePrice * 2 + 100 * 10 ** 8
      );
      assert.equal(
        bondGroupID.toString(),
        "0",
        "bond group id returned: " + bondGroupID.toString()
      );
    });
  });

  describe("settleTokens()", function () {
    let maturity;
    beforeEach(async () => {
      maturity = await setBonds.calcMaturity();
      await bondMakerInstance.registerBondPair(maturity, strikePrice);
      await aggregatorInstance.insertData(
        0,
        "50000000",
        "100000000",
        "100000000"
      );
    });

    it("only add liquidity", async () => {
      await aggregatorInstance.addLiquidity(lot);
      await aggregatorInstance.updateBondGroupData();
      await aggregatorInstance.settleTokens();
      const userData = await aggregatorInstance.getLiquidityReservationData(
        accounts[0]
      );
      assert.equal(userData[1].toString(), "0", "Should Delete userData");
      const balanceData = await aggregatorInstance.balanceOf(accounts[0]);
      assert.equal(
        balanceData.toString(),
        "200000000",
        "Value should be 2 token"
      );
    });

    it("nothing occurs before update bond group ID", async () => {
      await aggregatorInstance.addLiquidity(lot);
      await aggregatorInstance.settleTokens();
      const balanceData = await aggregatorInstance.balanceOf(accounts[0]);
      assert.equal(balanceData.toString(), "0", "Value should be 0.5 token");
    });

    it("only remove liquidity", async () => {
      await aggregatorInstance.addToken(accounts[0], 100000000);
      await collateralInstance.transfer(reserveERC20Instance.address, lot / 2);
      await aggregatorInstance.removeLiquidity(100000000);

      await aggregatorInstance.updateBondGroupData();
      await aggregatorInstance.settleTokens();
      const userData = await aggregatorInstance.getLiquidityReservationData(
        accounts[0]
      );
      assert.equal(userData[3].toString(), "0", "Should Delete userData");
      const balance = await collateralInstance.balanceOf(
        aggregatorInstance.address
      );
      assert.equal(balance.toString(), "0", "Value should be 0.5 eth");
    });

    it("nothing occurs before add aggregator", async () => {
      await aggregatorInstance.addToken(accounts[0], 100000000);

      await collateralInstance.transfer(reserveERC20Instance.address, lot);
      await aggregatorInstance.removeLiquidity(50000000);
      await aggregatorInstance.settleTokens();
      const balance = await collateralInstance.balanceOf(
        reserveERC20Instance.address
      );
      assert.equal(
        balance.toString(),
        String(10 ** 8),
        "Value should be 1 token"
      );
    });
  });

  describe("liquidateBonds()", function () {
    let BT1;
    let BT2;
    let BT3;
    let BT4;
    let BT5;
    let BT6;
    let BT7;
    let BT8;
    let BT9;
    let BT10;
    let BT11;
    let BT12;
    let BT13;
    let BT14;
    let maturity;
    beforeEach(async function () {
      maturity = await setBonds.calcMaturity();
      await bondMakerInstance.registerBondPair(maturity - 10, strikePrice);

      const BG0Info = await bondMakerInstance.getBondGroup(1);
      const bond1Info = await bondMakerInstance.getBond(BG0Info[0][0]);
      BT1 = await BT.at(bond1Info[0]);
      await BT1.mint(aggregatorInstance.address, 1000000);
      const bond2Info = await bondMakerInstance.getBond(BG0Info[0][1]);
      BT2 = await BT.at(bond2Info[0]);
      await BT2.mint(aggregatorInstance.address, 1000000);

      const BG1Info = await bondMakerInstance.getBondGroup(2);
      BG1IDs = BG1Info[0];
      const bond3Info = await bondMakerInstance.getBond(BG1Info[0][1]);
      BT3 = await BT.at(bond3Info[0]);
      await BT3.mint(aggregatorInstance.address, 1000000);
      const bond4Info = await bondMakerInstance.getBond(BG1Info[0][2]);
      BT4 = await BT.at(bond4Info[0]);
      await BT4.mint(aggregatorInstance.address, 1000000);
      const bond5Info = await bondMakerInstance.getBond(BG1Info[0][3]);
      BT5 = await BT.at(bond5Info[0]);
      await BT5.mint(aggregatorInstance.address, 1000000);

      await bondMakerInstance.registerBondPair(maturity - 10000, strikePrice);
      const BG2Info = await bondMakerInstance.getBondGroup(3);
      BG2IDs = BG2Info[0];
      const bond6Info = await bondMakerInstance.getBond(BG2Info[0][0]);
      BT6 = await BT.at(bond6Info[0]);
      await BT6.mint(aggregatorInstance.address, 1000000);
      const bond7Info = await bondMakerInstance.getBond(BG2Info[0][1]);
      BT7 = await BT.at(bond7Info[0]);
      await BT7.mint(aggregatorInstance.address, 1000000);

      const BG3Info = await bondMakerInstance.getBondGroup(4);
      const bond8Info = await bondMakerInstance.getBond(BG3Info[0][1]);
      BT8 = await BT.at(bond8Info[0]);
      await BT8.mint(aggregatorInstance.address, 1000000);
      const bond9Info = await bondMakerInstance.getBond(BG3Info[0][2]);
      BT9 = await BT.at(bond9Info[0]);
      await BT9.mint(aggregatorInstance.address, 1000000);
      const bond10Info = await bondMakerInstance.getBond(BG3Info[0][3]);
      BT10 = await BT.at(bond10Info[0]);
      await BT10.mint(aggregatorInstance.address, 1000000);
      await aggregatorInstance.updateBondGroupData();
    });

    it("Liquidate All bond", async () => {
      await time.increase(4000000);
      await aggregatorInstance.liquidateBonds();
      const BT1TotalSupply = await BT1.totalSupply();
      assert.equal(BT1TotalSupply.toString(), "0", "burn all BT1 token.");
      const BT2TotalSupply = await BT2.totalSupply();
      assert.equal(BT2TotalSupply.toString(), "0", "burn all BT2 token.");
      const BT3TotalSupply = await BT3.totalSupply();
      assert.equal(BT3TotalSupply.toString(), "0", "burn all BT3 token.");
      const BT4TotalSupply = await BT4.totalSupply();
      assert.equal(BT4TotalSupply.toString(), "0", "burn all BT4 token.");
      const BT5TotalSupply = await BT5.totalSupply();
      assert.equal(BT5TotalSupply.toString(), "0", "burn all BT5 token.");
      const BT6TotalSupply = await BT6.totalSupply();
      assert.equal(BT6TotalSupply.toString(), "0", "burn all BT6 token.");
      const BT7TotalSupply = await BT7.totalSupply();
      assert.equal(BT7TotalSupply.toString(), "0", "burn all BT7 token.");
      const BT8TotalSupply = await BT8.totalSupply();
      assert.equal(BT8TotalSupply.toString(), "0", "burn all BT8 token.");
      const BT9TotalSupply = await BT9.totalSupply();
      assert.equal(BT9TotalSupply.toString(), "0", "burn all BT9 token.");
      const BT10TotalSupply = await BT10.totalSupply();
      assert.equal(BT10TotalSupply.toString(), "0", "burn all BT10 token.");
    });
    it("check isLiquidated", async () => {
      await time.increase(4000000);
      const receipt = await aggregatorInstance.liquidateBonds();
      const isLiquidated = await aggregatorInstance.getLiquidationData(1);
      assert(isLiquidated[0], "should complete liquidation bonds");
    });

    describe("should not complete liquidation if bonds are more than 10", function () {
      beforeEach(async function () {
        await bondMakerInstance.registerBondPair(maturity - 20000, strikePrice);
        const BG4Info = await bondMakerInstance.getBondGroup(5);
        BG2IDs = BG4Info[0];
        const bond11Info = await bondMakerInstance.getBond(BG4Info[0][0]);
        BT11 = await BT.at(bond11Info[0]);
        const bond12Info = await bondMakerInstance.getBond(BG4Info[0][1]);
        BT12 = await BT.at(bond12Info[0]);
        await BT11.mint(aggregatorInstance.address, 1000000);

        await BT12.mint(aggregatorInstance.address, 1000000);
        await time.increase(4000000);
        const receipt = await aggregatorInstance.liquidateBonds();
      });

      it("check isLiquidated", async () => {
        const isLiquidated = await aggregatorInstance.getLiquidationData(1);
        assert(!isLiquidated[0], "should NOT complete liquidation bonds");
      });

      it("check liquidatedBondIndex", async function () {
        const liquidatedBondIndex = await aggregatorInstance.getLiquidationData(
          1
        );
        assert(
          liquidatedBondIndex[1].toString(),
          "10",
          "LiquidateBondIndex should be 10. But returned: " +
            liquidatedBondIndex[1].toString()
        );
      });
      it("Check TotalSupply of BT11 and BT12", async function () {
        const BT11TotalSupply = await BT11.totalSupply();
        assert(
          new BigNumber(BT11TotalSupply.toString()).gt(new BigNumber(0)),
          "should not burn all BT11 token."
        );
        const BT12TotalSupply = await BT12.totalSupply();
        assert(
          new BigNumber(BT12TotalSupply.toString()).gt(new BigNumber(0)),
          "should not burn all BT12 token."
        );
      });

      it("check isLiquidated after run one more liquidateBond()", async () => {
        const receipt = await aggregatorInstance.liquidateBonds();
        const isLiquidated = await aggregatorInstance.getLiquidationData(1);
        assert(isLiquidated[0], "should complete liquidation bonds");
      });

      it("check liquidatedBondIndex after run one more liquidateBond()", async function () {
        await aggregatorInstance.liquidateBonds();
        const liquidatedBondIndex = await aggregatorInstance.getLiquidationData(
          1
        );
        assert(
          liquidatedBondIndex[1].toString(),
          "10",
          "LiquidateBondIndex should be 10. But returned: " +
            liquidatedBondIndex[1].toString()
        );
      });
      it("check burn all bonds", async () => {
        await aggregatorInstance.liquidateBonds();
        const BT13TotalSupply = await BT11.totalSupply();
        assert.equal(BT13TotalSupply.toString(), "0", "burn all BT13 token.");
        const BT14TotalSupply = await BT12.totalSupply();
        assert.equal(BT14TotalSupply.toString(), "0", "burn all BT14 token.");
      });
    });
  });

  describe("_liquidateBondGroup", function () {
    let maturity;
    let previousmaturity;
    let BT1;
    beforeEach(async () => {
      maturity = await setBonds.calcMaturity();
      previousmaturity = maturity - 604800 * 3;
      await bondMakerInstance.registerBondPair(previousmaturity, strikePrice);
      await bondMakerInstance.registerBondPair(maturity, strikePrice);
      const BGInfo = await bondMakerInstance.getBondGroup(3);
      const bondInfo = await bondMakerInstance.getBond(BGInfo[0][1]);
      BT1 = await BT.at(bondInfo[0]);
      await BT1.mint(aggregatorInstance.address, 1000000);
    });
    describe("burn bond", function () {
      let receipt;
      beforeEach(async () => {
        receipt = await aggregatorInstance.liquidateBondGroup(
          3,
          0,
          maturity,
          previousmaturity
        );
      });
      it("check return value", async () => {
        //console.log(receipt.logs);
        assert.equal(
          receipt.logs[2].args.num.toString(),
          "1",
          "Invalid totalSupply returned" + receipt.logs[2].args.num.toString()
        );
      });
      it("check burn bond", async function () {
        const totalSupply = await BT1.totalSupply();
        assert.equal(
          totalSupply.toString(),
          "0",
          "Invalid totalSupply returned" + totalSupply.toString()
        );
      });
    });
    describe("not burn bond", function () {
      it("If privious maturity is larger than maturity", async function () {
        const receipt = await aggregatorInstance.liquidateBondGroup(
          3,
          0,
          maturity,
          maturity + 10000
        );
        assert.equal(
          receipt.logs[0].args.num.toString(),
          "0",
          "Invalid totalSupply returned" + receipt.logs[0].args.num.toString()
        );
      });

      it("If aggregator maturity is smaller than maturity", async function () {
        const receipt = await aggregatorInstance.liquidateBondGroup(
          3,
          0,
          maturity - 100000,
          previousmaturity
        );
        assert.equal(
          receipt.logs[0].args.num.toString(),
          "0",
          "Invalid totalSupply returned" + receipt.logs[0].args.num.toString()
        );
      });

      it("If aggregator does not have any bonds", async function () {
        const receipt = await aggregatorInstance.liquidateBondGroup(
          4,
          0,
          maturity - 100000,
          previousmaturity
        );
        assert.equal(
          receipt.logs[0].args.num.toString(),
          "0",
          "Invalid totalSupply returned" + receipt.logs[0].args.num.toString()
        );
      });
    });
  });

  describe("renewMaturity()", function () {
    let maturity;

    beforeEach(async () => {
      maturity = await setBonds.calcMaturity();
      await bondMakerInstance.registerBondPair(maturity, strikePrice);
    });
    describe("first time", function () {
      beforeEach(async () => {
        await aggregatorInstance.addLiquidity(lot);
        await aggregatorInstance.renewMaturity();
      });

      it("check total supply", async () => {
        const totalShare = await aggregatorInstance.totalShareData(1);
        assert.equal(
          totalShare[0].toString(),
          "100000000",
          "Invalid total share returned: " + totalShare.toString()
        );
      });

      it("check collateralPerToken", async () => {
        const collateralPerToken = await aggregatorInstance.getCollateralPerToken(
          1
        );
        assert.equal(
          collateralPerToken.toString(),
          "100000000",
          "Invalid collateralPerToken returned: " +
            collateralPerToken.toString()
        );
      });

      it("check eth balance of reserve", async () => {
        const balance = await collateralInstance.balanceOf(
          reserveERC20Instance.address
        );
        assert.equal(balance, 0, "invalid balance returned: " + balance);
      });

      describe("call twice", function () {
        beforeEach(async () => {
          await aggregatorInstance.settleTokens();

          await aggregatorInstance.addLiquidity(lot * 2);
          await aggregatorInstance.removeLiquidity(50000000);
          await time.increaseTo(maturity + 100);

          maturity = await setBonds.calcMaturity();
          await bondMakerInstance.registerBondPair(maturity, strikePrice);
          await aggregatorInstance.changeIsLiquidated();
          //await aggregatorInstance.liquidateBonds();
          await aggregatorInstance.renewMaturity();
        });
        it("check total supply", async () => {
          const totalShare = await aggregatorInstance.totalShareData(2);

          assert.equal(
            totalShare[0].toString(),
            "250000000",
            "Invalid total share returned: " + totalShare.toString()
          );
        });

        it("check collateralPerToken", async () => {
          const collateralPerToken = await aggregatorInstance.getCollateralPerToken(
            2
          );

          assert.equal(
            collateralPerToken.toString(),
            "100000000",
            "Invalid collateralPerToken returned: " +
              collateralPerToken.toString()
          );
        });

        it("check eth balance of reserve", async () => {
          const balance = await collateralInstance.balanceOf(
            reserveERC20Instance.address
          );

          assert.equal(
            balance.toString(),
            "50000000",
            "Invalid balance returned: " + balance
          );
        });
      });
    });
  });
  describe("ERC20 functions", function () {
    describe("transfer", function () {
      beforeEach(async () => {
        await aggregatorInstance.addToken(accounts[0], 100000000);
      });
      it("check transfer tokens", async () => {
        await aggregatorInstance.transfer(accounts[1], 30000000);
        assert.equal(
          (await aggregatorInstance.balanceOf(accounts[0])).toString(),
          "70000000",
          "Invalid balance of account1"
        );
        assert.equal(
          (await aggregatorInstance.balanceOf(accounts[1])).toString(),
          "30000000",
          "Invalid balance of account1"
        );
      });

      it("check transfer tokens if send amount exceeds balance", async () => {
        await aggregatorInstance.transfer(accounts[1], 110000000);
        assert.equal(
          (await aggregatorInstance.balanceOf(accounts[0])).toString(),
          "100000000",
          "Invalid balance of account1"
        );
        assert.equal(
          (await aggregatorInstance.balanceOf(accounts[1])).toString(),
          "0",
          "Invalid balance of account1"
        );
      });
    });

    describe("approve and allowance", function () {
      beforeEach(async () => {
        await aggregatorInstance.addToken(accounts[0], 100000000);
      });
      it("check approve #1", async () => {
        await aggregatorInstance.approve(accounts[1], 30000000);
        assert.equal(
          (
            await aggregatorInstance.allowance(accounts[0], accounts[1])
          ).toString(),
          "30000000",
          "Invalid balance of account1"
        );
      });
      it("check approve #2", async () => {
        await aggregatorInstance.approve(accounts[1], 130000000);
        assert.equal(
          (
            await aggregatorInstance.allowance(accounts[0], accounts[1])
          ).toString(),
          "130000000",
          "Invalid balance of account1"
        );
      });
      it("check inf approve", async () => {
        await aggregatorInstance.approve(accounts[1], inf);

        assert.equal(
          (
            await aggregatorInstance.allowance(accounts[0], accounts[1])
          ).toString(),
          inf_128,
          "Invalid balance of account1"
        );
      });
    });
    describe("transferFrom", function () {
      beforeEach(async () => {
        await aggregatorInstance.addToken(accounts[0], 100000000);
        await aggregatorInstance.approve(accounts[1], 30000000);
      });

      it("check transfer tokens account[0] to account[1]", async () => {
        await aggregatorInstance.transferFrom(
          accounts[0],
          accounts[1],
          30000000,
          {
            from: accounts[1],
          }
        );
        assert.equal(
          (await aggregatorInstance.balanceOf(accounts[0])).toString(),
          "70000000",
          "Invalid balance of account1"
        );
        assert.equal(
          (await aggregatorInstance.balanceOf(accounts[1])).toString(),
          "30000000",
          "Invalid balance of account1"
        );
        assert.equal(
          (
            await aggregatorInstance.allowance(accounts[0], accounts[1])
          ).toString(),
          "0",
          "Invalid allowance of account[0] to account[1]"
        );
      });

      it("check transfer tokens account[0] to account[2]", async () => {
        await aggregatorInstance.transferFrom(
          accounts[0],
          accounts[2],
          30000000,
          {
            from: accounts[1],
          }
        );
        assert.equal(
          (await aggregatorInstance.balanceOf(accounts[0])).toString(),
          "70000000",
          "Invalid balance of account1"
        );
        assert.equal(
          (await aggregatorInstance.balanceOf(accounts[2])).toString(),
          "30000000",
          "Invalid balance of account1"
        );
        assert.equal(
          (
            await aggregatorInstance.allowance(accounts[0], accounts[1])
          ).toString(),
          "0",
          "Invalid allowance of account[0] to account[1]"
        );
      });

      it("check transfer tokens account[0] to account[1] if amount exceeds allowance", async () => {
        await aggregatorInstance.transferFrom(
          accounts[0],
          accounts[1],
          50000000,
          {
            from: accounts[1],
          }
        );
        assert.equal(
          (await aggregatorInstance.balanceOf(accounts[0])).toString(),
          "100000000",
          "Invalid balance of account1"
        );
        assert.equal(
          (await aggregatorInstance.balanceOf(accounts[1])).toString(),
          "0",
          "Invalid balance of account1"
        );
        assert.equal(
          (
            await aggregatorInstance.allowance(accounts[0], accounts[1])
          ).toString(),
          "30000000",
          "Invalid allowance of account[0] to account[1]"
        );
      });
      it("check transfer tokens account[0] to account[1] if amount exceeds allowance", async () => {
        await aggregatorInstance.approve(accounts[1], inf);
        await aggregatorInstance.transferFrom(
          accounts[0],
          accounts[1],
          30000000,
          {
            from: accounts[1],
          }
        );
        assert.equal(
          (await aggregatorInstance.balanceOf(accounts[0])).toString(),
          "70000000",
          "Invalid balance of account1"
        );
        assert.equal(
          (await aggregatorInstance.balanceOf(accounts[1])).toString(),
          "30000000",
          "Invalid balance of account1"
        );
        assert.equal(
          (
            await aggregatorInstance.allowance(accounts[0], accounts[1])
          ).toString(),
          inf_128,
          "Invalid allowance of account[0] to account[1]"
        );
      });
    });
  });
  describe("total test", async () => {
    async function settle(aggregatorInstance, accounts) {
      await aggregatorInstance.settleTokens({ from: accounts[0] });
      await aggregatorInstance.settleTokens({ from: accounts[1] });
    }
    async function changeLiquidity(aggregatorInstance, amount) {
      if (amount > 0) {
        await collateralInstance.transfer(
          aggregatorInstance.address,
          Math.floor(amount * 10 ** 8)
        );
      } else if (amount < 0) {
        await aggregatorInstance.withdrawCollateral(
          Math.floor(amount * -1 * 10 ** 8)
        );
      }
    }
    const inputFile = "test/contract_test/unit_test/Aggregator/testCases.json";
    const data = JSON.parse(fs.readFileSync(inputFile, "utf8"));
    for (testCase of data.cases) {
      let maturity;
      let SBT;
      let calcedTotalSBT;
      describe("first term", function () {
        beforeEach(async () => {
          maturity = await strategyInstance.calcNextMaturity();
          await bondMakerInstance.registerBondPair(maturity, 40000000000);

          if (testCase.firstStage.LP1 > 0) {
            await aggregatorInstance.addLiquidity(
              Math.floor(testCase.firstStage.LP1 * 10 ** 8),
              {
                from: accounts[0],
              }
            );
          } else if (testCase.firstStage.LP1 < 0) {
            await aggregatorInstance.removeLiquidity(
              Math.floor(testCase.firstStage.LP1 * 10 ** 8 * -1),
              {
                from: accounts[0],
              }
            );
          }
          if (testCase.firstStage.LP2 > 0) {
            await aggregatorInstance.addLiquidity(
              Math.floor(testCase.firstStage.LP2 * 10 ** 8),
              {
                from: accounts[1],
              }
            );
          } else if (testCase.firstStage.LP2 < 0) {
            await aggregatorInstance.removeLiquidity(
              Math.floor(testCase.firstStage.LP2 * 10 ** 8 * -1),
              {
                from: accounts[1],
              }
            );
          }
          calcedTotalSBT = testCase.firstStage.TS * testCase.firstStage.EPT;
          maturity = await strategyInstance.calcNextMaturity();
          await aggregatorInstance.renewMaturity();
          await settle(aggregatorInstance, accounts);
        });
        it("check totalSupply of first stage", async () => {
          const totalSupply = await aggregatorInstance.totalSupply();
          assert.equal(
            totalSupply.toString(),
            String(testCase.firstStage.TS * 10 ** 8),
            "invalid totalSupply returned expected: " +
              String(testCase.firstStage.TS * 10 ** 8) +
              " got: " +
              totalSupply.toString()
          );
        });
        it("check ethPerToken of first stage", async () => {
          const EthPerToken = await aggregatorInstance.getCollateralPerToken(1);
          assert.equal(
            EthPerToken.toString(),
            String(testCase.firstStage.EPT * 10 ** 8),
            "invalid EthPerToken returned expected: " +
              String(testCase.firstStage.EPT * 10 ** 8) +
              " got: " +
              EthPerToken.toString()
          );
        });
        it("check balances of first stage", async () => {
          const L1Info = await aggregatorInstance.balanceOf(accounts[0]);
          assert.equal(
            L1Info.toString(),
            String(testCase.firstStage.LP1_A * 10 ** 8),
            "invalid share balance of LP returned expected: " +
              String(testCase.firstStage.LP1_A * 10 ** 8) +
              " got: " +
              L1Info.toString()
          );
          const L2Info = await aggregatorInstance.balanceOf(accounts[1]);
          assert.equal(
            L2Info.toString(),
            String(testCase.firstStage.LP2_A * 10 ** 8),
            "invalid share balance of LP2 returned expected: " +
              String(testCase.firstStage.LP2_A * 10 ** 8) +
              " got: " +
              L2Info.toString()
          );
        });

        describe("second term", function () {
          beforeEach(async () => {
            await bondMakerInstance.registerBondPair(maturity, 40000000000);
            if (testCase.secondStage.LP1 > 0) {
              await aggregatorInstance.addLiquidity(
                Math.floor(testCase.secondStage.LP1 * 10 ** 8),
                {
                  from: accounts[0],
                }
              );
            } else if (testCase.secondStage.LP1 < 0) {
              await aggregatorInstance.removeLiquidity(
                Math.floor(testCase.secondStage.LP1 * 10 ** 8 * -1),
                {
                  from: accounts[0],
                }
              );
            }

            if (testCase.secondStage.LP2 > 0) {
              await aggregatorInstance.addLiquidity(
                Math.floor(testCase.secondStage.LP2 * 10 ** 8),
                {
                  from: accounts[1],
                }
              );
            } else if (testCase.secondStage.LP2 < 0) {
              await aggregatorInstance.removeLiquidity(
                Math.floor(testCase.secondStage.LP2 * 10 ** 8 * -1),
                {
                  from: accounts[1],
                }
              );
            }
            calcedTotalSBT = testCase.secondStage.TS * testCase.secondStage.EPT;
            await changeLiquidity(
              aggregatorInstance,
              testCase.secondStage.changeLiquidity
            );
            await time.increaseTo(maturity.toNumber() + 100);
            await aggregatorInstance.liquidateBonds();
            maturity = await strategyInstance.calcNextMaturity();
            await aggregatorInstance.renewMaturity();
            await settle(aggregatorInstance, accounts);
          });
          it("check totalSupply of second stage", async () => {
            const totalSupply = await aggregatorInstance.totalSupply();
            assert.equal(
              totalSupply.toString(),
              String(testCase.secondStage.TS * 10 ** 8),
              "invalid totalSupply returned expected: " +
                String(testCase.secondStage.TS * 10 ** 8) +
                " got: " +
                totalSupply.toString()
            );
          });
          it("check ethPerToken of second stage", async () => {
            const EthPerToken = await aggregatorInstance.getCollateralPerToken(
              2
            );
            assert.equal(
              EthPerToken.toString(),
              String(Math.floor(testCase.secondStage.EPT * 10 ** 8)),
              "invalid EthPerToken returned expected: " +
                String(Math.floor(testCase.secondStage.EPT * 10 ** 8)) +
                " got: " +
                EthPerToken.toString()
            );
          });
          it("check balances of second stage", async () => {
            const L1Info = await aggregatorInstance.balanceOf(accounts[0]);
            assert.equal(
              L1Info.toString(),
              String(testCase.secondStage.LP1_A * 10 ** 8),
              "invalid share balance of LP returned expected: " +
                String(testCase.secondStage.LP1_A * 10 ** 8) +
                " got: " +
                L1Info.toString()
            );
            const L2Info = await aggregatorInstance.balanceOf(accounts[1]);
            assert.equal(
              L2Info.toString(),
              String(testCase.secondStage.LP2_A * 10 ** 8),
              "invalid share balance of LP2 returned expected: " +
                String(testCase.secondStage.LP2_A * 10 ** 8) +
                " got: " +
                L2Info.toString()
            );
          });

          describe("third term", function () {
            beforeEach(async () => {
              await bondMakerInstance.registerBondPair(maturity, 40000000000);
              if (testCase.thirdStage.LP1 > 0) {
                await aggregatorInstance.addLiquidity(
                  Math.floor(testCase.thirdStage.LP1 * 10 ** 8),
                  {
                    from: accounts[0],
                  }
                );
              } else if (testCase.thirdStage.LP1 < 0) {
                await aggregatorInstance.removeLiquidity(
                  Math.floor(testCase.thirdStage.LP1 * 10 ** 8 * -1),
                  {
                    from: accounts[0],
                  }
                );
              }

              if (testCase.thirdStage.LP2 > 0) {
                await aggregatorInstance.addLiquidity(
                  Math.floor(testCase.thirdStage.LP2 * 10 ** 8),
                  {
                    from: accounts[1],
                  }
                );
              } else if (testCase.thirdStage.LP2 < 0) {
                await aggregatorInstance.removeLiquidity(
                  Math.floor(testCase.thirdStage.LP2 * 10 ** 8 * -1),
                  {
                    from: accounts[1],
                  }
                );
              }

              calcedTotalSBT = testCase.thirdStage.TS * testCase.thirdStage.EPT;
              await changeLiquidity(
                aggregatorInstance,
                testCase.thirdStage.changeLiquidity
              );
              await time.increaseTo(maturity.toNumber() + 100);
              await aggregatorInstance.liquidateBonds();
              maturity = await strategyInstance.calcNextMaturity();
              await aggregatorInstance.renewMaturity();
              await settle(aggregatorInstance, accounts);
            });
            it("check totalSupply of third stage", async () => {
              const totalSupply = await aggregatorInstance.totalSupply();
              assert.equal(
                totalSupply.toString(),
                String(testCase.thirdStage.TS * 10 ** 8),
                "invalid totalSupply returned expected: " +
                  String(testCase.thirdStage.TS * 10 ** 8) +
                  " got: " +
                  totalSupply.toString()
              );
            });
            it("check ethPerToken of third stage", async () => {
              const EthPerToken = await aggregatorInstance.getCollateralPerToken(
                3
              );
              assert.equal(
                EthPerToken.toString(),
                String(Math.floor(testCase.thirdStage.EPT * 10 ** 8)),
                "invalid EthPerToken returned expected: " +
                  String(Math.floor(testCase.thirdStage.EPT * 10 ** 8)) +
                  " got: " +
                  EthPerToken.toString()
              );
            });
            it("check balances of third stage", async () => {
              const L1Info = await aggregatorInstance.balanceOf(accounts[0]);
              assert.equal(
                L1Info.toString(),
                String(testCase.thirdStage.LP1_A * 10 ** 8),
                "invalid share balance of LP returned expected: " +
                  String(testCase.thirdStage.LP1_A * 10 ** 8) +
                  " got: " +
                  L1Info.toString()
              );
              const L2Info = await aggregatorInstance.balanceOf(accounts[1]);
              assert.equal(
                L2Info.toString(),
                String(testCase.thirdStage.LP2_A * 10 ** 8),
                "invalid share balance of LP2 returned expected: " +
                  String(testCase.thirdStage.LP2_A * 10 ** 8) +
                  " got: " +
                  L2Info.toString()
              );
            });
          });
        });
      });
    }
  });
});