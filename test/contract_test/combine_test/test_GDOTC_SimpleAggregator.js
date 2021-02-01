const ZAddress = "0x0000000000000000000000000000000000000000";
const ZBytes32 =
  "0x0000000000000000000000000000000000000000000000000000000000000000";
const Aggregator = artifacts.require("testSimpleAggregatorCollateralizedEth");
const AggregatorERC20 = artifacts.require(
  "testSimpleAggregatorCollateralizedERC20"
);
const testStrategy = artifacts.require("MockSimpleStrategy2");
const BigNumber = require("bignumber.js");
const Registrator = artifacts.require("testBondRegistrator");
const BondMaker = artifacts.require("BondMakerCollateralizedEth");
const Strategy = artifacts.require("StrategyForSimpleAggregatorETH");
const Exchange = artifacts.require("GeneralizedDotc");
const USDCOracle = artifacts.require("USDCOracle");
const BondMakerERC20 = artifacts.require("BondMakerCollateralizedErc20");
const Oracle = artifacts.require("testOracleForAggregator");
const GeneralizedPricing = artifacts.require("GeneralizedPricing");
const Pricer = artifacts.require("BondPricerWithAcceptableMaturity");
const Detector = artifacts.require("DetectBondShape");
const Generator = artifacts.require("fnMapGenerator");
const BT = artifacts.require("testBondToken");
const testBT = artifacts.require("testBondToken");
const BTFactory = artifacts.require("BondTokenFactory");
const BTName = artifacts.require("BondTokenName");
const VolOracle = artifacts.require("testVolatilityOracle");
const { time, expectRevert } = require("@openzeppelin/test-helpers");
const setBonds = require("../../utils/setBond.js");
const constants = require("../../utils/constants.js");
const priceUnit = 1000000000;

contract("Combine test: GDOTC-ETHAggregator", function (accounts) {
  const termInterval = 604800; // 1 week in sec

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
    const usdOracleInstance = await USDCOracle.new();
    exchangeInstance = await Exchange.new(
      bondMakerInstance.address,
      volOracleInstance.address,
      usdOracleInstance.address,
      detectorInstance.address
    );
    strategyInstance = await Strategy.new(
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

    generatorInstance = await Generator.new();
    await pricerInstance.transferOwnership(aggregatorInstance.address);
    await strategyInstance.registerAggregators(
      oracleInstance.address,
      false,
      [aggregatorInstance.address],
      100,
      50
    );
    maturity = await strategyInstance.calcNextMaturity();
  });

  describe("Trade", () => {
    let maturity;
    describe("Valid bond group", () => {
      let validBondInstance;
      beforeEach(async function () {
        maturity = await setBonds.calcMaturity();
        await setBonds.registerBondGroupForRBM(
          constants.testCaseETH,
          maturity,
          bondMakerInstance,
          generatorInstance,
          undefined
        );
        await aggregatorInstance.addLiquidity({
          value: web3.utils.toWei("20", "ether"),
        });

        await aggregatorInstance.renewMaturity();
        await aggregatorInstance.trancheBonds();
        const ethAllowance = await exchangeInstance.ethAllowance(
          aggregatorInstance.address
        );
        // allowance is 2 eth
        assert.equal(
          ethAllowance.toString(),
          new BigNumber(2 * 10 ** 18).toString(),
          "Invalid allowance"
        );

        const BGInfo = await bondMakerInstance.getBondGroup(1);
        const bondInfo = await bondMakerInstance.getBond(BGInfo[0][0]);
        validBondInstance = await BT.at(bondInfo[0]);
        await bondMakerInstance.issueNewBonds(1, {
          value: web3.utils.toWei("1", "ether"),
        });
        const poolID = await exchangeInstance.generateVsEthPoolID(
          aggregatorInstance.address,
          false
        );
        await validBondInstance.approve(exchangeInstance.address, 10 ** 8);
        await exchangeInstance.exchangeBondToEth(
          BGInfo[0][0],
          poolID,
          10 ** 6,
          web3.utils.toWei("0.005", "ether"),
          500
        );
      });
      it("check bond balance", async () => {
        const bondBalance = await validBondInstance.balanceOf(accounts[0]);
        assert.equal(
          bondBalance.toString(),
          "98800399",
          "Almost 0.1 bond token transfered"
        );
      });
      it("check eth allowance", async () => {
        const ethAllowance = await exchangeInstance.ethAllowance(
          aggregatorInstance.address
        );
        // allowance decreases 1.5 eth for 0.01 SBT (half price of eth)
        assert.equal(
          ethAllowance.toString(),
          "1995125000000000000",
          "Invalid allowance"
        );
      });
    });
    describe("Revert for Invalid bond group", () => {
      it("bond has already expired", async () => {
        maturity = await setBonds.calcMaturity();
        await setBonds.registerBondGroupForRBM(
          constants.testCaseETH,
          maturity,
          bondMakerInstance,
          generatorInstance,
          undefined
        );
        await bondMakerInstance.issueNewBonds(1, {
          value: web3.utils.toWei("1", "ether"),
        });
        await time.increaseTo(maturity);
        maturity = await setBonds.calcMaturity();
        await aggregatorInstance.addLiquidity({
          value: web3.utils.toWei("20", "ether"),
        });

        await aggregatorInstance.renewMaturity();
        await aggregatorInstance.trancheBonds();

        const BGInfo = await bondMakerInstance.getBondGroup(1);
        const bondInfo = await bondMakerInstance.getBond(BGInfo[0][0]);
        validBondInstance = await BT.at(bondInfo[0]);
        const poolID = await exchangeInstance.generateVsEthPoolID(
          aggregatorInstance.address,
          false
        );
        await validBondInstance.approve(exchangeInstance.address, 10 ** 8);
        await expectRevert.unspecified(
          exchangeInstance.exchangeBondToEth(
            BGInfo[0][0],
            poolID,
            10 ** 6,
            web3.utils.toWei("0.0005", "ether"),
            1000
          )
        );
      });

      it("maturity is too long", async () => {
        maturity = await setBonds.calcMaturity();
        await setBonds.registerBondGroupForRBM(
          constants.testCaseETH,
          maturity + 1000000,
          bondMakerInstance,
          generatorInstance,
          undefined
        );
        await aggregatorInstance.addLiquidity({
          value: web3.utils.toWei("20", "ether"),
        });

        await aggregatorInstance.renewMaturity();
        await aggregatorInstance.trancheBonds();

        const BGInfo = await bondMakerInstance.getBondGroup(1);
        const bondInfo = await bondMakerInstance.getBond(BGInfo[0][0]);
        validBondInstance = await BT.at(bondInfo[0]);
        await bondMakerInstance.issueNewBonds(1, {
          value: web3.utils.toWei("1", "ether"),
        });
        const poolID = await exchangeInstance.generateVsEthPoolID(
          aggregatorInstance.address,
          false
        );
        await validBondInstance.approve(exchangeInstance.address, 10 ** 8);
        await expectRevert.unspecified(
          exchangeInstance.exchangeBondToEth(
            BGInfo[0][0],
            poolID,
            10 ** 6,
            web3.utils.toWei("0.0005", "ether"),
            1000
          )
        );
      });
    });
  });

  describe("check default pool", function () {
    it("check bond maker contract", async function () {
      const info = await aggregatorInstance.getInfo();
      assert.equal(
        info[0],
        bondMakerInstance.address,
        "Invalid bondmaker Address"
      );
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
        "Invalid oracle Address"
      );
      assert.equal(
        poolData[2],
        pricerInstance.address,
        "Invalid pricer Address"
      );
      assert.equal(poolData[3].toString(), "250", "Invalid feebase");
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
      assert.equal(poolData[3].toString(), "250", "Invalid feebase");
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
      assert.equal(poolData[5].toString(), "250", "Invalid feebase");
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
        "999600000000000000",
        ethBalance.toString(),
        "Invalid ETH Allowance"
      );
    });
  });
});

contract("Combine test: GDOTC-ERC20Aggregator", function (accounts) {
  const termInterval = 604800; // 1 week in sec
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
  let rewardInstance;
  let registratorInstance;

  beforeEach(async () => {
    volOracleInstance = await VolOracle.new();
    oracleInstance = await Oracle.new();
    const generalizedPricer = await GeneralizedPricing.new();
    pricerInstance = await Pricer.new(generalizedPricer.address);
    BTFactoryInstance = await BTFactory.new();
    BTNameInstance = await BTName.new();
    detectorInstance = await Detector.new();
    collateralInstance = await BT.new();
    await collateralInstance.changeDecimal(8);
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
    exchangeInstance = await Exchange.new(
      bondMakerInstance.address,
      volOracleInstance.address,
      oracleInstance.address,
      detectorInstance.address
    );
    strategyInstance = await testStrategy.new();
    generatorInstance = await Generator.new();
    maturity = await strategyInstance.calcNextMaturity();
    registratorInstance = await Registrator.new();
    rewardInstance = await BT.new();

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
    await oracleInstance.changePriceAndVolatility(
      125000,
      new BigNumber(10 ** 7)
    );
    await collateralInstance.mint(accounts[0], new BigNumber(10 ** 10));
    await collateralInstance.approve(
      aggregatorInstance.address,
      new BigNumber(10 ** 10)
    );
    await collateralInstance.approve(
      bondMakerInstance.address,
      new BigNumber(10 ** 10)
    );
    await collateralInstance.approve(
      exchangeInstance.address,
      new BigNumber(10 ** 10)
    );
    await pricerInstance.transferOwnership(aggregatorInstance.address);
  });

  describe("Trade", () => {
    let maturity;
    describe("Valid bond group", () => {
      let validBondInstance;
      beforeEach(async function () {
        maturity = await setBonds.calcMaturity();
        await setBonds.registerBondGroupForRBM(
          constants.testCaseERC20,
          maturity,
          bondMakerInstance,
          generatorInstance,
          undefined
        );
        await aggregatorInstance.addLiquidity(new BigNumber(10 ** 8));

        await aggregatorInstance.renewMaturity();

        const BGInfo = await bondMakerInstance.getBondGroup(1);
        const bondInfo = await bondMakerInstance.getBond(BGInfo[0][0]);
        validBondInstance = await BT.at(bondInfo[0]);
        await bondMakerInstance.issueNewBonds(1, new BigNumber(10 ** 8));
        const poolID = await exchangeInstance.generateVsErc20PoolID(
          aggregatorInstance.address,
          collateralInstance.address,
          false
        );
        await validBondInstance.approve(exchangeInstance.address, 10 ** 8);
        await exchangeInstance.exchangeBondToErc20(
          BGInfo[0][0],
          poolID,
          10 ** 6,
          1000,
          1000
        );
      });
      it("check bond balance", async () => {
        const bondBalance = await validBondInstance.balanceOf(accounts[0]);

        assert.equal(
          bondBalance.toString(),
          "98800399",
          "Almost 0.1 bond token transfered"
        );
      });
      it("check collateral token balance", async () => {
        const balance = await collateralInstance.balanceOf(accounts[0]);

        assert.equal(
          balance.toString(),
          new BigNumber(9800001201).toString(),
          "Invalid eth balance"
        );
      });
    });
    describe("Revert for Invalid bond group", () => {
      it("bond has already expired", async () => {
        maturity = await setBonds.calcMaturity();
        await setBonds.registerBondGroupForRBM(
          constants.testCaseERC20,
          maturity,
          bondMakerInstance,
          generatorInstance,
          undefined
        );
        await bondMakerInstance.issueNewBonds(1, new BigNumber(10 ** 8));
        await time.increaseTo(maturity);
        maturity = await setBonds.calcMaturity();

        await aggregatorInstance.addLiquidity(new BigNumber(20 * 10 ** 8));
        await aggregatorInstance.renewMaturity();

        const BGInfo = await bondMakerInstance.getBondGroup(1);
        const bondInfo = await bondMakerInstance.getBond(BGInfo[0][0]);
        validBondInstance = await BT.at(bondInfo[0]);
        const poolID = await exchangeInstance.generateVsErc20PoolID(
          aggregatorInstance.address,
          collateralInstance.address,
          false
        );
        await validBondInstance.approve(exchangeInstance.address, 10 ** 8);
        await expectRevert.unspecified(
          exchangeInstance.exchangeBondToErc20(
            BGInfo[0][0],
            poolID,
            10 ** 6,
            1000,
            1000
          )
        );
      });

      it("maturity is too long", async () => {
        maturity = await setBonds.calcMaturity();
        await setBonds.registerBondGroupForRBM(
          constants.testCaseERC20,
          maturity + 100000,
          bondMakerInstance,
          generatorInstance,
          undefined
        );
        await aggregatorInstance.addLiquidity(new BigNumber(20 * 10 ** 8));

        await aggregatorInstance.renewMaturity();

        const BGInfo = await bondMakerInstance.getBondGroup(1);
        const bondInfo = await bondMakerInstance.getBond(BGInfo[0][0]);
        validBondInstance = await BT.at(bondInfo[0]);
        await bondMakerInstance.issueNewBonds(1, new BigNumber(20 * 10 ** 8));
        const poolID = await exchangeInstance.generateVsErc20PoolID(
          aggregatorInstance.address,
          collateralInstance.address,
          false
        );
        await validBondInstance.approve(exchangeInstance.address, 10 ** 8);
        await expectRevert.unspecified(
          exchangeInstance.exchangeBondToErc20(
            BGInfo[0][0],
            poolID,
            10 ** 6,
            1000,
            1000
          )
        );
      });
    });
  });

  describe("check default pool", function () {
    it("check bond maker contract", async function () {
      const info = await aggregatorInstance.getInfo();
      assert.equal(
        info[0],
        bondMakerInstance.address,
        "Invalid bondmaker Address"
      );
    });

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
      assert.equal(poolData[4].toString(), "250", "Invalid feebase");
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
      assert.equal(poolData[4].toString(), "250", "Invalid feebase");
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
      assert.equal(poolData[5].toString(), "250", "Invalid feebase");
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
