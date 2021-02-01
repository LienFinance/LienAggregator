const ZAddress = "0x0000000000000000000000000000000000000000";
const Oracle = artifacts.require("testOracleForAggregator");
const BondMaker = artifacts.require("TestBondMaker");
const Strategy = artifacts.require("testSimpleStrategy");
const Aggregator = artifacts.require("MockSimpleAggregator");
const BT = artifacts.require("testBondToken");
const ethAmount = web3.utils.toWei("0.1", "ether");
const BigNumber = require("bignumber.js");
const eth = web3.utils.toWei("1", "ether");
const Exchange = artifacts.require("TestExchange");
const { time, expectRevert } = require("@openzeppelin/test-helpers");
const fs = require("fs");
const currentPrice = 40000000000;
const ethVolatility = 10000000;
const priceUnit = 1000000000;
const setBonds = require("../../../utils/setBond.js");

contract("Strategy", function (accounts) {
  let oracleInstance;
  let bondMakerInstance;
  let aggregatorInstance;
  let strategyInstance;
  const inputFile = "test/contract_test/unit_test/Strategy/testCases.json";
  const data = JSON.parse(fs.readFileSync(inputFile, "utf8"));
  beforeEach(async function () {
    oracleInstance = await Oracle.new();
    aggregatorInstance = await Aggregator.new();
    bondMakerInstance = await BondMaker.new();
    exchangeInstance = await Exchange.new(bondMakerInstance.address);
    strategyInstance = await Strategy.new(
      exchangeInstance.address,
      604800,
      144000
    );
  });

  describe("applydecimal Gap", function () {
    it("vs USDC", async function () {
      const ans = await strategyInstance.applyDecimalGap(10 ** 6, -2);
      assert.equal(
        ans.toString(),
        "100000000",
        "Invalid value returned: " + ans.toString()
      );
    });
    it("vs ETH", async function () {
      const ans = await strategyInstance.applyDecimalGap(eth, 10);
      assert.equal(
        ans.toString(),
        "100000000",
        "Invalid value returned: " + ans.toString()
      );
    });

    it("vs LIEN", async function () {
      const ans = await strategyInstance.applyDecimalGap(10 ** 8, 0);
      assert.equal(
        ans.toString(),
        "100000000",
        "Invalid value returned: " + ans.toString()
      );
    });
  });

  describe("calcRoundPrice", function () {
    it("#1", async function () {
      const ans = await strategyInstance.calcRoundPrice(
        414 * 10 ** 8,
        10 ** 9,
        1
      );
      assert.equal(
        ans.toString(),
        "41000000000",
        "expect $400 but returned: " + ans.toString()
      );
    });
    it("#2", async function () {
      const ans = await strategyInstance.calcRoundPrice(
        814 * 10 ** 8,
        25 * 10 ** 8,
        1
      );
      assert.equal(
        ans.toString(),
        "80000000000",
        "expect $800 but returned: " + ans.toString()
      );
    });
    it("#3", async function () {
      const ans = await strategyInstance.calcRoundPrice(
        414 * 10 ** 8,
        10 ** 9,
        2
      );
      assert.equal(
        ans.toString(),
        "20000000000",
        "expect $200 but returned: " + ans.toString()
      );
    });
    it("#4", async function () {
      const ans = await strategyInstance.calcRoundPrice(
        814 * 10 ** 8,
        25 * 10 ** 8,
        2
      );
      assert.equal(
        ans.toString(),
        "40000000000",
        "expect $400 but returned: " + ans.toString()
      );
    });
  });

  describe("reversed value", function () {
    it("if non reversed oracle", async function () {
      const ans = await strategyInstance.getReversedValue(400 * 10 ** 8, false);
      assert.equal(
        ans.toString(),
        "40000000000",
        "expect $400 but returned: " + ans.toString()
      );
    });
    it("if reversed oracle", async function () {
      const ans = await strategyInstance.getReversedValue(400 * 10 ** 8, true);
      assert.equal(
        ans.toString(),
        "250000",
        "expect 250000 but returned: " + ans.toString()
      );
    });
  });

  describe("calcCallStrikePrice", function () {
    it("price unit $10, non reversed oracle", async function () {
      const ans = await strategyInstance.calcCallStrikePrice(
        412 * 10 ** 8,
        10 ** 9,
        false
      );
      assert.equal(
        ans.toString(),
        "41000000000",
        "expect $400 but returned: " + ans.toString()
      );
    });

    it("price unit $25, non reversed oracle", async function () {
      const ans = await strategyInstance.calcCallStrikePrice(
        837 * 10 ** 8,
        25 * 10 ** 8,
        false
      );
      assert.equal(
        ans.toString(),
        "82500000000",
        "expect $825 but returned: " + ans.toString()
      );
    });

    it("price unit $10, reversed oracle", async function () {
      const ans = await strategyInstance.calcCallStrikePrice(
        402 * 10 ** 8,
        10 ** 9,
        true
      );
      assert.equal(
        ans.toString(),
        "250000",
        "expect 250000 but returned: " + ans.toString()
      );
    });

    it("price unit $25, reversed oracle", async function () {
      const ans = await strategyInstance.calcCallStrikePrice(
        837 * 10 ** 8,
        25 * 10 ** 8,
        true
      );
      assert.equal(
        ans.toString(),
        "121212",
        "expect 121212 but returned: " + ans.toString()
      );
    });
  });

  describe("getBaseAmount", function () {
    it("Vs ETH", async function () {
      await aggregatorInstance.changeData(ZAddress, eth, 18);
      const ans = await strategyInstance.getBaseAmount(
        aggregatorInstance.address
      );
      assert.equal(
        ans.toString(),
        "20000000",
        "Invalid value returned: " + ans.toString()
      );
    });
    it("Vs USDC", async function () {
      await aggregatorInstance.changeData(
        aggregatorInstance.address,
        10 ** 6,
        6
      );
      const ans = await strategyInstance.getBaseAmount(
        aggregatorInstance.address
      );
      assert.equal(
        ans.toString(),
        "20000000",
        "Invalid value returned: " + ans.toString()
      );
    });
    it("Vs LIEN", async function () {
      await aggregatorInstance.changeData(
        aggregatorInstance.address,
        10 ** 8,
        8
      );
      const ans = await strategyInstance.getBaseAmount(
        aggregatorInstance.address
      );
      assert.equal(
        ans.toString(),
        "20000000",
        "Invalid value returned: " + ans.toString()
      );
    });
  });

  describe("getLBTStrikePrice", function () {
    for (let i = 0; i < data.validCases.length; i++) {
      it("get Call Option Price", async function () {
        const maturity = await setBonds.calcMaturity();
        const testCase = data.validCases[i];
        await setBonds.registerBondGroup(testCase, maturity, bondMakerInstance);
        const LBTPrice = await strategyInstance.getLBTStrikePrice(
          bondMakerInstance.address,
          2,
          false
        );
        assert.equal(
          Number(LBTPrice[0].toString()),
          data.validCases[i].strikePriceCall * 10 ** 8,
          "Invalid LBT Price Returned: " + LBTPrice[0].toString()
        );
      });
    }
  });

  describe("getLBTStrikePrice for ERC20", function () {
    for (let i = 0; i < data.validCasesERC20.length; i++) {
      it("get Call Option Price", async function () {
        const maturity = await setBonds.calcMaturity();
        const testCase = data.validCasesERC20[i];
        await setBonds.registerBondGroup(testCase, maturity, bondMakerInstance);
        const LBTPrice = await strategyInstance.getLBTStrikePrice(
          bondMakerInstance.address,
          2,
          true
        );
        assert.equal(
          Number(LBTPrice[0].toString()),
          Math.floor(1 / data.validCasesERC20[i].strikePriceCall) * 10 ** 8,
          "Invalid LBT Price Returned: " + LBTPrice[0].toString()
        );
      });
    }
  });

  describe("getCurrentStrikePrice", function () {
    it("should return 200 for low volatility", async function () {
      await oracleInstance.changePriceAndVolatility(40000000000, 10000000);
      const strikePrice = await strategyInstance.getCurrentStrikePrice(
        currentPrice,
        priceUnit,
        false
      );

      assert.equal(
        strikePrice.toString(),
        "20000000000",
        "Invalid strike price returned: " + strikePrice.toString()
      );
    });

    it("should return 200 for high volatility", async function () {
      await oracleInstance.changePriceAndVolatility(40000000000, 500000000);
      const strikePrice = await strategyInstance.getCurrentStrikePrice(
        currentPrice,
        priceUnit,
        false
      );

      // console.log(strikePrice.toString());

      assert.equal(
        strikePrice.toString(),
        "20000000000",
        "Invalid strike price returned: " + strikePrice.toString()
      );
    });

    it("should return 200 for low volatility", async function () {
      await oracleInstance.changePriceAndVolatility(40000000000, 10000000);
      const strikePrice = await strategyInstance.getCurrentStrikePrice(
        currentPrice,
        priceUnit,
        true
      );
      //console.log(strikePrice.toString());

      assert.equal(
        strikePrice.toString(),
        "125000",
        "Invalid strike price returned: " + strikePrice.toString()
      );
    });
    it("should return 200 for high volatility", async function () {
      await oracleInstance.changePriceAndVolatility(40000000000, 500000000);
      const strikePrice = await strategyInstance.getCurrentStrikePrice(
        currentPrice,
        priceUnit,
        true
      );
      // console.log(strikePrice.toString());

      assert.equal(
        strikePrice.toString(),
        "125000",
        "Invalid strike price returned: " + strikePrice.toString()
      );
    });
  });

  describe("getMinBondAmount", function () {
    let SBTInstance;
    let CallInstance;
    let Lev2Instance;
    let VolShortInstance;
    beforeEach(async function () {
      const maturity = await setBonds.calcMaturity();
      await bondMakerInstance.registerBondPair(maturity, 400 * 10 ** 8);
      const BGInfo = await bondMakerInstance.getBondGroup(2);
      const SBTInfo = await bondMakerInstance.getBond(BGInfo[0][0]);
      SBTInstance = await BT.at(SBTInfo[0]);
      const CallInfo = await bondMakerInstance.getBond(BGInfo[0][1]);
      CallInstance = await BT.at(CallInfo[0]);
      const Lev2Info = await bondMakerInstance.getBond(BGInfo[0][2]);
      Lev2Instance = await BT.at(Lev2Info[0]);
      const VolShortInfo = await bondMakerInstance.getBond(BGInfo[0][3]);
      VolShortInstance = await BT.at(VolShortInfo[0]);
    });
    it("Minimum bond is SBT", async () => {
      await SBTInstance.mint(accounts[1], 90000);
      await CallInstance.mint(accounts[1], 100000);
      await Lev2Instance.mint(accounts[1], 100000);
      await VolShortInstance.mint(accounts[1], 100000);
      const balance = await strategyInstance.getMinBondAmount(
        bondMakerInstance.address,
        2,
        accounts[1]
      );
      assert.equal(
        balance.toString(),
        "90000",
        "Invalid amount returned: " + balance.toString()
      );
    });
    it("Minimum bond is Call", async () => {
      await SBTInstance.mint(accounts[1], 100000);
      await CallInstance.mint(accounts[1], 90000);
      await Lev2Instance.mint(accounts[1], 100000);
      await VolShortInstance.mint(accounts[1], 100000);
      const balance = await strategyInstance.getMinBondAmount(
        bondMakerInstance.address,
        2,
        accounts[1]
      );
      assert.equal(
        balance.toString(),
        "90000",
        "Invalid amount returned: " + balance.toString()
      );
    });
    it("Minimum bond is Lev", async () => {
      await SBTInstance.mint(accounts[1], 100000);
      await CallInstance.mint(accounts[1], 100000);
      await Lev2Instance.mint(accounts[1], 90000);
      await VolShortInstance.mint(accounts[1], 100000);
      const balance = await strategyInstance.getMinBondAmount(
        bondMakerInstance.address,
        2,
        accounts[1]
      );
      assert.equal(
        balance.toString(),
        "90000",
        "Invalid amount returned: " + balance.toString()
      );
    });
    it("Minimum bond is VolShort", async () => {
      await SBTInstance.mint(accounts[1], 100000);
      await CallInstance.mint(accounts[1], 100000);
      await Lev2Instance.mint(accounts[1], 100000);
      await VolShortInstance.mint(accounts[1], 90000);
      const balance = await strategyInstance.getMinBondAmount(
        bondMakerInstance.address,
        2,
        accounts[1]
      );
      assert.equal(
        balance.toString(),
        "90000",
        "Invalid amount returned: " + balance.toString()
      );
    });
  });

  describe("calcNextMaturity", function () {
    it("check maturity #1", async function () {
      const correctMaturity = await setBonds.calcMaturity();
      const calculatedMaturity = await strategyInstance.calcNextMaturity();
      assert.equal(
        String(correctMaturity),
        calculatedMaturity.toString(),
        "Invalid maturity"
      );
    });

    it("check maturity #2", async function () {
      const correctMaturity = await setBonds.calcMaturity();
      await time.increaseTo(correctMaturity - 604800 * 2 - 100);
      const calculatedMaturity = await strategyInstance.calcNextMaturity();
      assert.equal(
        String(correctMaturity),
        calculatedMaturity.toString(),
        "Invalid maturity"
      );
    });

    it("check maturity #3", async function () {
      const firstMaturity = await setBonds.calcMaturity();
      await time.increaseTo(firstMaturity + 100);
      const correctMaturity = await setBonds.calcMaturity();
      const calculatedMaturity = await strategyInstance.calcNextMaturity();
      assert.equal(
        String(correctMaturity),
        calculatedMaturity.toString(),
        "Invalid maturity"
      );
    });
  });

  describe("register fee base", function () {
    let aggregatorID0;
    let aggregatorID1;
    beforeEach(async () => {
      await strategyInstance.registerAggregators(
        accounts[0],
        true,
        [accounts[0]],
        100,
        50
      );
      await strategyInstance.registerAggregators(
        accounts[0],
        false,
        [accounts[1]],
        100,
        50
      );
      aggregatorID0 = await strategyInstance.generateAggregatorID(
        accounts[0],
        accounts[0],
        true
      );
      aggregatorID1 = await strategyInstance.generateAggregatorID(
        accounts[0],
        accounts[0],
        false
      );
    });
    it("check register aggregator #1", async () => {
      const accounts0 = await strategyInstance.aggregators(aggregatorID0, 0);
      assert.equal(accounts0, accounts[0]);
    });
    it("check register FeeInfo #1", async () => {
      const feeInfo = await strategyInstance.getFeeInfo(
        accounts[0],
        accounts[0],
        true
      );
      assert.equal(feeInfo[0], "250");
      assert.equal(feeInfo[1], "100");
      assert.equal(feeInfo[2], "50");
    });
    it("check register aggregator #2", async () => {
      const accounts1 = await strategyInstance.aggregators(aggregatorID1, 0);
      assert.equal(accounts1, accounts[1]);
    });
    it("check register FeeInfo #2", async () => {
      const feeInfo = await strategyInstance.getFeeInfo(
        accounts[0],
        accounts[0],
        false
      );
      assert.equal(feeInfo[0], "250");
      assert.equal(feeInfo[1], "100");
      assert.equal(feeInfo[2], "50");
    });

    it("register current feebase (upward)", async () => {
      await strategyInstance.registerCurrentFeeBase(
        400,
        105000010,
        100000000,
        accounts[0],
        accounts[0],
        true
      );
      const feeBase = await strategyInstance.getCurrentSpread(
        accounts[0],
        accounts[0],
        true
      );
      assert.equal(
        feeBase.toString(),
        "500",
        "invalid feebase returned: " + feeBase.toString()
      );
    });
    it("register current feebase (downward)", async () => {
      await strategyInstance.registerCurrentFeeBase(
        550,
        100000000,
        105000010,
        accounts[0],
        accounts[0],
        true
      );
      const feeBase = await strategyInstance.getCurrentSpread(
        accounts[0],
        accounts[0],
        true
      );
      assert.equal(
        feeBase.toString(),
        "500",
        "invalid feebase returned: " + feeBase.toString()
      );
    });
    it("register current feebase if under initial feebase", async () => {
      await strategyInstance.registerCurrentFeeBase(
        200,
        100000000,
        105000010,
        accounts[0],
        accounts[0],
        true
      );
      const feeBase = await strategyInstance.getCurrentSpread(
        accounts[0],
        accounts[0],
        true
      );
      assert.equal(
        feeBase.toString(),
        "250",
        "invalid feebase returned: " + feeBase.toString()
      );
    });
    it("register current feebase if over 1000", async () => {
      await strategyInstance.registerCurrentFeeBase(
        1000,
        105000010,
        100000000,
        accounts[0],
        accounts[0],
        true
      );
      const feeBase = await strategyInstance.getCurrentSpread(
        accounts[0],
        accounts[0],
        true
      );
      assert.equal(
        feeBase.toString(),
        "999",
        "invalid feebase returned: " + feeBase.toString()
      );
    });
    it("revert for invalid aggregator", async () => {
      await expectRevert.unspecified(
        strategyInstance.registerCurrentFeeBase(
          500,
          105000010,
          100000000,
          accounts[0],
          accounts[0],
          false
        )
      );
    });
  });

  describe("getTrancheBonds", function () {
    for (let i = 0; i < 6; i++) {
      it("return valid order for tranching bond", async function () {
        const maturity = await setBonds.calcMaturity();
        await setBonds.registerTrancheBonds(
          data.TrancheBonds[i],
          maturity,
          bondMakerInstance,
          oracleInstance,
          aggregatorInstance
        );
        const ans = await strategyInstance.getTrancheBonds(
          bondMakerInstance.address,
          aggregatorInstance.address,
          data.TrancheBonds[i].issueBondGroup,
          currentPrice,
          data.TrancheBonds[i].bondGroups,
          priceUnit,
          false
        );
        const list = ans[2];
        assert.equal(
          ans[0].toString(),
          String(data.TrancheBonds[i].issueAmount),
          "Invalid Amount returned" + ans[0].toString()
        );

        for (let j = 1; j < list.length; j++) {
          const correctAmount = data.TrancheBonds[i].returnedAmounts[j];
          assert.equal(
            list[j].toString(),
            correctAmount,
            "Invalid Value Expected: " +
              correctAmount +
              " Actual: " +
              list[j].toString()
          );
        }
      });
    }

    it("return valid order for tranching bond when lev2 token's balance is reduced", async function () {
      const maturity = await setBonds.calcMaturity();
      await setBonds.registerTrancheBonds(
        data.TrancheBonds[0],
        maturity,
        bondMakerInstance,
        oracleInstance,
        aggregatorInstance
      );

      const BGInfo = await bondMakerInstance.getBondGroup(4);
      const BondInfo = await bondMakerInstance.getBond(BGInfo[0][3]);
      await aggregatorInstance.transferToken(BondInfo[0], 100, {
        from: accounts[0],
      });

      const ans = await strategyInstance.getTrancheBonds(
        bondMakerInstance.address,
        aggregatorInstance.address,
        data.TrancheBonds[0].issueBondGroup,
        currentPrice,
        data.TrancheBonds[0].bondGroups,
        priceUnit,
        false
      );
      const list = ans[2];

      const correctAmount =
        Number(data.TrancheBonds[0].returnedAmounts[1]) - 100;
      assert.equal(
        list[1].toString(),
        String(correctAmount),
        "Invalid Value Expected: " +
          correctAmount +
          " Actual: " +
          list[1].toString()
      );
    });
  });

  describe("getTrancheBonds for ERC20", function () {
    for (let i = 0; i < 1; i++) {
      it("return valid order for tranching bond", async function () {
        const maturity = await setBonds.calcMaturity();
        await setBonds.registerTrancheBonds(
          data.TrancheBondsERC20[i],
          maturity,
          bondMakerInstance,
          oracleInstance,
          aggregatorInstance
        );
        const ans = await strategyInstance.getTrancheBonds(
          bondMakerInstance.address,
          aggregatorInstance.address,
          data.TrancheBondsERC20[i].issueBondGroup,
          currentPrice,
          data.TrancheBondsERC20[i].bondGroups,
          priceUnit,
          true
        );
        const list = ans[2];
        assert.equal(
          ans[0].toString(),
          String(data.TrancheBondsERC20[i].issueAmount),
          "Invalid Amount returned" + ans[0].toString()
        );

        for (let j = 1; j < list.length; j++) {
          const correctAmount = data.TrancheBondsERC20[i].returnedAmounts[j];
          assert.equal(
            list[j].toString(),
            correctAmount,
            "Invalid Value Expected: " +
              correctAmount +
              " Actual: " +
              list[j].toString()
          );
        }
      });
    }

    it("return valid order for tranching bond when lev2 token's balance is reduced", async function () {
      const maturity = await setBonds.calcMaturity();
      await setBonds.registerTrancheBonds(
        data.TrancheBondsERC20[0],
        maturity,
        bondMakerInstance,
        oracleInstance,
        aggregatorInstance
      );

      const BGInfo = await bondMakerInstance.getBondGroup(4);
      const BondInfo = await bondMakerInstance.getBond(BGInfo[0][3]);
      await aggregatorInstance.transferToken(BondInfo[0], 100, {
        from: accounts[0],
      });

      const ans = await strategyInstance.getTrancheBonds(
        bondMakerInstance.address,
        aggregatorInstance.address,
        data.TrancheBondsERC20[0].issueBondGroup,
        currentPrice,
        data.TrancheBondsERC20[0].bondGroups,
        priceUnit,
        true
      );
      const list = ans[2];

      const correctAmount =
        Number(data.TrancheBondsERC20[0].returnedAmounts[1]) - 100;
      assert.equal(
        list[1].toString(),
        String(correctAmount),
        "Invalid Value Expected: " +
          correctAmount +
          " Actual: " +
          list[1].toString()
      );
    });
  });
});
