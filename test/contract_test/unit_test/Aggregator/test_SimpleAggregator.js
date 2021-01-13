const Aggregator = artifacts.require("testSimpleAggregatorCollateralizedEth");
const BondMaker = artifacts.require("TestBondMaker");
const Reserve = artifacts.require("ReserveEth");
const Oracle = artifacts.require("testOracleForAggregator");
const Strategy = artifacts.require("MockSimpleStrategy2");
const Exchange = artifacts.require("TestExchange");
const Pricer = artifacts.require("testGeneralizedPricing");
const VolOracle = artifacts.require("testVolatilityOracle");
const BT = artifacts.require("testBondToken");
const ERC20 = artifacts.require("ERC20");
const BigNumber = require("bignumber.js");
const priceUnit = 1000000000;
const strikePrice = 20000000000;
const { time, expectRevert } = require("@openzeppelin/test-helpers");
const inf =
  "115792089237316195423570985008687907853269984665640564039457584007913129639935";
const inf_128 = "340282366920938463463374607431768211455";

contract("simple aggregator", function (accounts) {
  let oracleInstance;
  let pricerInstance;
  let aggregatorInstance;
  let bondMakerInstance;
  let strategyInstance;
  let exchangeInstance;
  let volOracleInstance;
  let reserveEthInstance;
  async function calcMaturity() {
    const block = await web3.eth.getBlock("latest");
    const timestamp = block.timestamp;
    const weeks = Math.floor(timestamp / 608000);
    return (Number(weeks) + 3) * 608000 + 144000;
  }
  beforeEach(async () => {
    volOracleInstance = await VolOracle.new();
    exchangeInstance = await Exchange.new();
    oracleInstance = await Oracle.new();
    pricerInstance = await Pricer.new();
    bondMakerInstance = await BondMaker.new();
    strategyInstance = await Strategy.new(bondMakerInstance.address);
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
    reserveEthInstance = await Reserve.at(
      await aggregatorInstance.getReserveAddress()
    );
  });

  describe("Launch contract", function () {
    describe("check default pool", function () {
      it("check eth sell pool", async function () {
        const poolID = await exchangeInstance.generateVsEthPoolID(
          aggregatorInstance.address,
          true
        );
        const poolData = await exchangeInstance.getEthPoolData(poolID);
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
        assert.equal(poolData[2], 100, "Invalid feebase");
        assert(poolData[3], "This pool should be sell");
      });

      it("check eth buy pool", async function () {
        const poolID = await exchangeInstance.generateVsEthPoolID(
          aggregatorInstance.address,
          false
        );
        const poolData = await exchangeInstance.getEthPoolData(poolID);
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
        assert.equal(poolData[2], 100, "Invalid feebase");
        assert(!poolData[3], "This pool should be buy");
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
        assert.equal(poolData[3], 100, "Invalid feebase");
      });
    });

    describe("chenge spread", function () {
      beforeEach(async () => {
        await strategyInstance.changeSpread(50);
        await aggregatorInstance.changeSpread();
      });

      it("check eth sell pool", async function () {
        const poolID = await exchangeInstance.generateVsEthPoolID(
          aggregatorInstance.address,
          true
        );
        const poolData = await exchangeInstance.getEthPoolData(poolID);
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
        assert.equal(poolData[2], 50, "Invalid feebase");
        assert(poolData[3], "This pool should be sell");
      });

      it("check eth buy pool", async function () {
        const poolID = await exchangeInstance.generateVsEthPoolID(
          aggregatorInstance.address,
          false
        );
        const poolData = await exchangeInstance.getEthPoolData(poolID);
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
        assert.equal(poolData[2], 50, "Invalid feebase");
        assert(!poolData[3], "This pool should be buy");
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

  describe("updateBondGroupData", function () {
    let maturity;
    let receipt;
    let bondIDs;
    let info;
    beforeEach(async () => {
      maturity = await calcMaturity();
      receipt = await aggregatorInstance.updateBondGroupData();
      info = await aggregatorInstance.getInfo();
    });
    it("check current term", async () => {
      assert.equal(info[6].toString(), "1", "should increment term");
    });
    it("check maturity", async () => {
      assert.equal(info[4].toString(), maturity.toString(), "invalid maturity");
    });
    it("check strikePrice", async () => {
      assert.equal(
        info[5].toString(),
        strikePrice.toString(),
        "invalid strike price"
      );
    });
  });

  describe("add liquidity", () => {
    describe("for the first term", () => {
      beforeEach(async () => {
        await aggregatorInstance.addLiquidity({
          value: web3.utils.toWei("1", "ether"),
        });
      });

      it("check liquidity data", async () => {
        const userData = await aggregatorInstance.getReceivedETHs(accounts[0]);
        assert.equal(userData[0].toString(), "0", "term should be 0");
        assert.equal(
          userData[1].toString(),
          web3.utils.toWei("1", "ether").toString(),
          "Value should be 1ETH"
        );
      });
      it("check total liquidity to add", async () => {
        const total = await aggregatorInstance.getTotalUnmovedAssets();
        assert.equal(
          total[0].toString(),
          web3.utils.toWei("1", "ether").toString(),
          "Total Value should be 1ETH"
        );
      });
    });
    describe("for the second term", () => {
      let maturity;
      beforeEach(async () => {
        maturity = await calcMaturity();
        await bondMakerInstance.registerBondPair(maturity, strikePrice);
        await aggregatorInstance.updateBondGroupData();
        await aggregatorInstance.addLiquidity({
          value: web3.utils.toWei("1", "ether"),
        });
      });

      it("check liquidity data", async () => {
        const userData = await aggregatorInstance.getReceivedETHs(accounts[0]);
        assert.equal(userData[0].toString(), "1", "term should be 1");
        assert.equal(
          userData[1].toString(),
          web3.utils.toWei("1", "ether").toString(),
          "Value should be 1ETH"
        );
      });
      it("check total liquidity to add", async () => {
        const total = await aggregatorInstance.getTotalUnmovedAssets();
        assert.equal(
          total[0].toString(),
          web3.utils.toWei("1", "ether").toString(),
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
        const userData = await aggregatorInstance.getUnremovedTokens(
          accounts[0]
        );
        assert.equal(userData[0].toString(), "0", "term should be 0");
        assert.equal(
          userData[1].toString(),
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
        maturity = await calcMaturity();
        await bondMakerInstance.registerBondPair(maturity, strikePrice);
        await aggregatorInstance.updateBondGroupData();
        await aggregatorInstance.addLiquidity({
          value: web3.utils.toWei("1", "ether"),
        });
        await aggregatorInstance.removeLiquidity(50000000);
      });

      it("check liquidity data", async () => {
        const userData = await aggregatorInstance.getUnremovedTokens(
          accounts[0]
        );
        assert.equal(userData[0].toString(), "1", "term should be 1");
        assert.equal(
          userData[1].toString(),
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

  describe("addIssuableBondGroup()", function () {
    let maturity;
    beforeEach(async function () {
      maturity = await calcMaturity();
      await bondMakerInstance.registerBondPair(maturity, strikePrice);
      await aggregatorInstance.updateBondGroupData();
    });

    it("should revert when invalid bondgroup", async function () {
      await bondMakerInstance.registerBondPair(maturity + 100000, strikePrice);
      await expectRevert.unspecified(
        aggregatorInstance.addIssuableBondGroup(4)
      );
    });

    it("should revert when aggregator has already the same bondGroup", async function () {
      await time.increase(400000);
      await aggregatorInstance.addIssuableBondGroup(2);
      await expectRevert.unspecified(
        aggregatorInstance.addIssuableBondGroup(2)
      );
    });

    it("check infinity approve", async function () {
      const inf =
        "115792089237316195423570985008687907853269984665640564039457584007913129639935";

      await time.increase(400000);
      await aggregatorInstance.addIssuableBondGroup(2);
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

    it("check issuableBondIDs", async function () {
      await time.increase(400000);
      await aggregatorInstance.addIssuableBondGroup(2);
      const isIssuable = await aggregatorInstance.isIssuableGroupID(2, 1);
      assert(isIssuable, "This bondgroup should be issuable");
      const firstIssuableBondGroup = await aggregatorInstance.getIssuableBondGroupIds(
        0
      );
      assert.equal(
        firstIssuableBondGroup.toString(),
        "2",
        "BondGroup 2 should be added to issuableBondGroupIds"
      );
    });
  });

  describe("settleTokens()", function () {
    let maturity;
    beforeEach(async () => {
      maturity = await calcMaturity();
      await bondMakerInstance.registerBondPair(maturity, strikePrice);
      await aggregatorInstance.insertData(
        0,
        "50000000",
        "100000000",
        "100000000"
      );
    });

    it("only add liquidity", async () => {
      await aggregatorInstance.addLiquidity({
        value: web3.utils.toWei("1", "ether"),
      });
      await aggregatorInstance.updateBondGroupData();
      await aggregatorInstance.settleTokens();
      const userData = await aggregatorInstance.getReceivedETHs(accounts[0]);
      assert.equal(userData[1].toString(), "0", "Should Delete userData");
      const balanceData = await aggregatorInstance.balanceOf(accounts[0]);
      assert.equal(
        balanceData.toString(),
        "200000000",
        "Value should be 2 token"
      );
    });

    it("nothing occurs before update bond group ID", async () => {
      await aggregatorInstance.addLiquidity({
        value: web3.utils.toWei("1", "ether"),
      });
      await aggregatorInstance.settleTokens();
      const balanceData = await aggregatorInstance.balanceOf(accounts[0]);
      assert.equal(balanceData.toString(), "0", "Value should be 0.5 token");
    });

    it("only remove liquidity", async () => {
      await aggregatorInstance.addToken(accounts[0], 100000000);
      await reserveEthInstance.sendTransaction({
        from: accounts[0],
        value: web3.utils.toWei("0.5", "ether"),
      });
      await aggregatorInstance.removeLiquidity(100000000);

      await aggregatorInstance.updateBondGroupData();
      await aggregatorInstance.settleTokens();
      const userData = await aggregatorInstance.getUnremovedTokens(accounts[0]);
      assert.equal(userData[1].toString(), "0", "Should Delete userData");
      const balance = await web3.eth.getBalance(aggregatorInstance.address);
      assert.equal(balance, 0, "Value should be 0.5 eth");
    });

    it("nothing occurs before add aggregator", async () => {
      await aggregatorInstance.addToken(accounts[0], 100000000);
      await reserveEthInstance.sendTransaction({
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      });
      await aggregatorInstance.removeLiquidity(50000000);
      await aggregatorInstance.settleTokens();
      const balance = await web3.eth.getBalance(reserveEthInstance.address);
      assert.equal(
        balance,
        web3.utils.toWei("1", "ether"),
        "Value should be 0.5 token"
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
      maturity = await calcMaturity();
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
      const isLiquidated = await aggregatorInstance.getIsLiquidated(1);
      assert(isLiquidated, "should complete liquidation bonds");
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
        const isLiquidated = await aggregatorInstance.getIsLiquidated(1);
        assert(!isLiquidated, "should NOT complete liquidation bonds");
      });

      it("check liquidatedBondIndex", async function () {
        const liquidatedBondIndex = await aggregatorInstance.getLiquidatedBondIndex();
        assert(
          liquidatedBondIndex.toString(),
          "10",
          "LiquidateBondIndex should be 10. But returned: " +
            liquidatedBondIndex.toString()
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
        const isLiquidated = await aggregatorInstance.getIsLiquidated(1);
        assert(isLiquidated, "should complete liquidation bonds");
      });

      it("check liquidatedBondIndex after run one more liquidateBond()", async function () {
        await aggregatorInstance.liquidateBonds();
        const liquidatedBondIndex = await aggregatorInstance.getLiquidatedBondIndex();
        assert(
          liquidatedBondIndex.toString(),
          "10",
          "LiquidateBondIndex should be 10. But returned: " +
            liquidatedBondIndex.toString()
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
      maturity = await calcMaturity();
      previousmaturity = maturity - 608000 * 3;
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
          receipt.logs[3].args.number.toString(),
          "1",
          "Invalid totalSupply returned" +
            receipt.logs[3].args.number.toString()
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
          receipt.logs[0].args.number.toString(),
          "0",
          "Invalid totalSupply returned" +
            receipt.logs[0].args.number.toString()
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
          receipt.logs[0].args.number.toString(),
          "0",
          "Invalid totalSupply returned" +
            receipt.logs[0].args.number.toString()
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
          receipt.logs[0].args.number.toString(),
          "0",
          "Invalid totalSupply returned" +
            receipt.logs[0].args.number.toString()
        );
      });
    });
  });

  describe("renewMaturity()", function () {
    let maturity;

    beforeEach(async () => {
      maturity = await calcMaturity();
      await bondMakerInstance.registerBondPair(maturity, strikePrice);
    });
    describe("first time", function () {
      beforeEach(async () => {
        await aggregatorInstance.addLiquidity({
          value: web3.utils.toWei("1", "ether"),
        });
        await aggregatorInstance.renewMaturity();
      });

      it("check total supply", async () => {
        const totalShare = await aggregatorInstance.totalSupplyTermOf(1);
        assert.equal(
          totalShare.toString(),
          "100000000",
          "Invalid total share returned: " + totalShare.toString()
        );
      });

      it("check ethPerToken", async () => {
        const ethPerToken = await aggregatorInstance.getCollateralPerToken(1);
        assert.equal(
          ethPerToken.toString(),
          "100000000",
          "Invalid ethPerToken returned: " + ethPerToken.toString()
        );
      });

      it("check eth balance of reserve", async () => {
        const balance = await web3.eth.getBalance(reserveEthInstance.address);
        assert.equal(balance, 0, "invalid balance returned: " + balance);
      });

      describe("call twice", function () {
        beforeEach(async () => {
          await aggregatorInstance.settleTokens();

          await aggregatorInstance.addLiquidity({
            value: web3.utils.toWei("2", "ether"),
          });
          await aggregatorInstance.removeLiquidity(50000000);
          await time.increaseTo(maturity + 100);

          maturity = await calcMaturity();
          await bondMakerInstance.registerBondPair(maturity, strikePrice);
          await aggregatorInstance.changeIsLiquidated();
          //await aggregatorInstance.liquidateBonds();
          await aggregatorInstance.renewMaturity();
        });
        it("check total supply", async () => {
          const totalShare = await aggregatorInstance.totalSupplyTermOf(2);

          assert.equal(
            totalShare.toString(),
            "250000000",
            "Invalid total share returned: " + totalShare.toString()
          );
        });

        it("check ethPerToken", async () => {
          const ethPerToken = await aggregatorInstance.getCollateralPerToken(2);

          assert.equal(
            ethPerToken.toString(),
            "100000000",
            "Invalid ethPerToken returned: " + ethPerToken.toString()
          );
        });

        it("check eth balance of reserve", async () => {
          const balance = await web3.eth.getBalance(reserveEthInstance.address);
          assert.equal(
            balance.toString(),
            "499999980000000000",
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
});
