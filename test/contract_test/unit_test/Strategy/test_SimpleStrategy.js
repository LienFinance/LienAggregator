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
const {time, expectRevert} = require("@openzeppelin/test-helpers");
const fs = require("fs");
const currentPrice = 40000000000;
const ethVolatility = 10000000;
const priceUnit = 1000000000;
async function calcMaturity() {
  const block = await web3.eth.getBlock("latest");
  const timestamp = block.timestamp;
  const weeks = Math.floor(timestamp / 608000);
  return (Number(weeks) + 3) * 608000 + 144000;
}
async function registerBondGroup(testCase, maturity, bondMakerInstance) {
  const priceMultiplyer = 10 ** 8;
  const maxProfitVolShort = Math.floor(
    ((testCase.strikePriceCall - testCase.strikePriceSBT) *
      (testCase.strikePriceCall - testCase.Lev2EndPoint)) /
      (testCase.strikePriceSBT - testCase.Lev2EndPoint)
  );
  let receipt = await bondMakerInstance.resisterFnMap([
    0,
    0,
    testCase.strikePriceSBT * priceMultiplyer,
    testCase.strikePriceSBT * priceMultiplyer,
    testCase.strikePriceSBT * priceMultiplyer,
    testCase.strikePriceSBT * priceMultiplyer,
    testCase.strikePriceSBT * priceMultiplyer * 2,
    testCase.strikePriceSBT * priceMultiplyer,
  ]);
  const SBTFnMapID = receipt.logs[0].args.fnMapID;

  receipt = await bondMakerInstance.resisterFnMap([
    0,
    0,
    testCase.strikePriceCall * priceMultiplyer,
    0,
    testCase.strikePriceCall * priceMultiplyer,
    0,
    testCase.strikePriceCall * priceMultiplyer * 2,
    testCase.strikePriceCall * priceMultiplyer,
  ]);
  const LBTFnMapID = receipt.logs[0].args.fnMapID;
  receipt = await bondMakerInstance.resisterFnMap([
    0,
    0,
    testCase.strikePriceSBT * priceMultiplyer,
    0,

    testCase.strikePriceSBT * priceMultiplyer,
    0,
    testCase.Lev2EndPoint * priceMultiplyer,
    testCase.strikePriceCall * priceMultiplyer -
      testCase.strikePriceSBT * priceMultiplyer,

    testCase.Lev2EndPoint * priceMultiplyer,
    testCase.strikePriceCall * priceMultiplyer -
      testCase.strikePriceSBT * priceMultiplyer,
    testCase.Lev2EndPoint * priceMultiplyer * 2,
    testCase.strikePriceCall * priceMultiplyer -
      testCase.strikePriceSBT * priceMultiplyer,
  ]);
  const Lev2FnMapID = receipt.logs[0].args.fnMapID;
  receipt = await bondMakerInstance.resisterFnMap([
    0,
    0,
    testCase.strikePriceSBT * priceMultiplyer,
    0,
    testCase.strikePriceSBT * priceMultiplyer,
    0,
    testCase.strikePriceCall * priceMultiplyer,
    maxProfitVolShort * priceMultiplyer,
    testCase.strikePriceCall * priceMultiplyer,
    maxProfitVolShort * priceMultiplyer,
    testCase.Lev2EndPoint * priceMultiplyer,
    0,
    testCase.Lev2EndPoint * priceMultiplyer,
    0,
    testCase.Lev2EndPoint * priceMultiplyer * 2,
    0,
  ]);
  const VolSFnMapID = receipt.logs[0].args.fnMapID;
  await bondMakerInstance.registerBondPair2(
    maturity,
    testCase.strikePriceSBT * priceMultiplyer,
    [SBTFnMapID, LBTFnMapID, Lev2FnMapID, VolSFnMapID]
  );
  return {SBTFnMapID, LBTFnMapID, Lev2FnMapID, VolSFnMapID};
}
async function registerTrancheBonds(
  testCase,
  maturity,
  bondMakerInstance,
  oracleInstance,
  aggregatorInstance
) {
  await oracleInstance.changePriceAndVolatility(
    testCase.ethPrice * 10 ** 8,
    testCase.ethVolatility * 10 ** 6
  );
  for (let i = 0; i < testCase.bonds.length; i++) {
    await registerBondGroup(testCase.bonds[i], maturity, bondMakerInstance);
    const bondgroupInfo = await bondMakerInstance.getBondGroup((i + 1) * 2);
    let bondInfo = await bondMakerInstance.getBond(bondgroupInfo[0][0]);
    let bond = await BT.at(bondInfo[0]);
    await bond.mint(aggregatorInstance.address, testCase.amounts[i]);
    bondInfo = await bondMakerInstance.getBond(bondgroupInfo[0][1]);
    bond = await BT.at(bondInfo[0]);
    await bond.mint(aggregatorInstance.address, testCase.amounts[i]);
    bondInfo = await bondMakerInstance.getBond(bondgroupInfo[0][2]);
    bond = await BT.at(bondInfo[0]);
    await bond.mint(aggregatorInstance.address, testCase.amounts[i]);
    bondInfo = await bondMakerInstance.getBond(bondgroupInfo[0][3]);
    bond = await BT.at(bondInfo[0]);
    // console.log(testCase.amounts[i]);
    await bond.mint(aggregatorInstance.address, testCase.amounts[i]);
  }

  await aggregatorInstance.changeData(true, testCase.baseAmount * 10 ** 10, 18);
}

contract("Strategy", function (accounts) {
  let oracleInstance;
  let bondMakerInstance;
  let aggregatorInstance;
  let strategyInstance;
  const inputFile = "test/contract_test/unit_test/Strategy/testCases.json";
  const data = JSON.parse(fs.readFileSync(inputFile, "utf8"));
  beforeEach(async function () {
    exchangeInstance = await Exchange.new();
    oracleInstance = await Oracle.new();
    aggregatorInstance = await Aggregator.new();
    bondMakerInstance = await BondMaker.new();
    strategyInstance = await Strategy.new(
      exchangeInstance.address,
      608000,
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

  describe("getBaseAmount", function () {
    it("Vs ETH", async function () {
      await aggregatorInstance.changeData(true, eth, 18);
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
      await aggregatorInstance.changeData(false, 10 ** 6, 6);
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
      await aggregatorInstance.changeData(false, 10 ** 8, 8);
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
        const maturity = await calcMaturity();
        const testCase = data.validCases[i];
        await registerBondGroup(testCase, maturity, bondMakerInstance);
        const LBTPrice = await strategyInstance.getLBTStrikePrice(
          bondMakerInstance.address,
          2
        );
        assert.equal(
          Number(LBTPrice[0].toString()),
          data.validCases[i].strikePriceCall * 10 ** 8,
          "Invalid LBT Price Returned: " + LBTPrice[0].toString()
        );
      });
    }
  });

  describe("isValidLBT", function () {
    for (let i = 0; i < data.validCases.length; i++) {
      it("valid LBT", async function () {
        const maturity = await calcMaturity();
        const testCase = data.validCases[i];
        await registerBondGroup(testCase, maturity, bondMakerInstance);
        const isValidLBT = await strategyInstance.isValidLBT(
          bondMakerInstance.address,
          2,
          data.validCases[i].strikePriceCall * 10 ** 8,
          data.validCases[i].strikePriceSBT * 10 ** 8,
          maturity,
          priceUnit
        );
        assert(isValidLBT, "This Bond should be valid");
      });
      it("Invalid LBT for bond order", async function () {
        const maturity = await calcMaturity();
        const testCase = data.validCases[i];
        const fnMaps = await registerBondGroup(
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
        const isValidLBT = await strategyInstance.isValidLBT(
          bondMakerInstance.address,
          4,
          data.validCases[i].strikePriceCall * 10 ** 8,
          data.validCases[i].strikePriceSBT * 10 ** 8,
          maturity,
          priceUnit
        );
        assert(!isValidLBT, "This Bond should be invalid");
      });
      it("invalid LBT for strike price", async function () {
        const maturity = await calcMaturity();
        const testCase = data.validCases[i];
        await registerBondGroup(testCase, maturity, bondMakerInstance);
        const isValidLBT = await strategyInstance.isValidLBT(
          bondMakerInstance.address,
          2,
          data.validCases[i].strikePriceCall * 10 ** 8,
          data.validCases[i].strikePriceSBT * 10 ** 8 + 100000,
          maturity,
          priceUnit
        );
        assert(!isValidLBT, "This Bond should be invalid");
      });

      it("invalid LBT for maturity", async function () {
        const maturity = await calcMaturity();
        const testCase = data.validCases[i];
        await registerBondGroup(testCase, maturity, bondMakerInstance);
        const isValidLBT = await strategyInstance.isValidLBT(
          bondMakerInstance.address,
          2,
          data.validCases[i].strikePriceCall * 10 ** 8,
          data.validCases[i].strikePriceSBT * 10 ** 8 + 100000,
          maturity,
          priceUnit
        );
        assert(!isValidLBT, "This Bond should be invalid");
      });
    }

    for (let i = 0; i < data.invalidCases.length; i++) {
      it("invalid LBT", async function () {
        const maturity = await calcMaturity();
        const testCase = data.invalidCases[i];
        await registerBondGroup(testCase, maturity, bondMakerInstance);
        const isValidLBT = await strategyInstance.isValidLBT(
          bondMakerInstance.address,
          2,
          data.invalidCases[i].strikePriceCall * 10 ** 8,
          data.invalidCases[i].strikePriceSBT * 10 ** 4,
          maturity,
          priceUnit
        );
        assert(!isValidLBT, "This Bond should be invalid");
      });
    }
  });

  describe("getCurrentStrikePrice", function () {
    it("should return 200 for low volatility", async function () {
      await oracleInstance.changePriceAndVolatility(40000000000, 10000000);
      const maturity = await calcMaturity();
      const strikePrice = await strategyInstance.getCurrentStrikePrice(
        maturity,
        currentPrice,
        ethVolatility,
        priceUnit
      );
      assert.equal(
        strikePrice.toString(),
        "20000000000",
        "Invalid strike price returned: " + strikePrice.toString()
      );
    });
  });

  describe("getTrancheBonds", function () {
    for (let i = 0; i < data.TrancheBonds.length; i++) {
      it("return valid order for tranching bond", async function () {
        const maturity = await calcMaturity();
        await registerTrancheBonds(
          data.TrancheBonds[i],
          maturity,
          bondMakerInstance,
          oracleInstance,
          aggregatorInstance
        );
        const list = await strategyInstance.getTrancheBonds(
          bondMakerInstance.address,
          aggregatorInstance.address,
          currentPrice,
          data.TrancheBonds[i].bondGroups,
          priceUnit
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
      const maturity = await calcMaturity();
      await registerTrancheBonds(
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

      const list = await strategyInstance.getTrancheBonds(
        bondMakerInstance.address,
        aggregatorInstance.address,
        currentPrice,
        data.TrancheBonds[0].bondGroups,
        priceUnit
      );

      const correctAmount =
        Number(data.TrancheBonds[0].returnedAmounts[4]) + 100;
      assert.equal(
        list[4].toString(),
        String(correctAmount),
        "Invalid Value Expected: " +
          correctAmount +
          " Actual: " +
          list[2].toString()
      );
    });
  });
});
