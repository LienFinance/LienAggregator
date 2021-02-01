const GeneralizedPricing = artifacts.require("GeneralizedPricing");
const Pricer = artifacts.require("testBondPricerWithAcceptableMaturity");
const { expectRevert } = require("@openzeppelin/test-helpers");

contract("BondPricerWithAcceptableMaturity", function (accounts) {
  let pricerInstance;
  const ETHPrice = "80000000000";
  const Vol = "10000000";
  beforeEach(async () => {
    const generalizedPricer = await GeneralizedPricing.new();
    pricerInstance = await Pricer.new(generalizedPricer.address);
  });
  describe("updateAcceptableMaturity", function () {
    it("update maturity", async () => {
      const block = await web3.eth.getBlock("latest");
      const maturityTimestamp = block.timestamp + 1000;
      await pricerInstance.updateAcceptableMaturity(maturityTimestamp);
      const currentMaturity = await pricerInstance.getAcceptableMaturity();
      assert.equal(
        String(maturityTimestamp),
        currentMaturity.toString(),
        "Invalid maturity registered"
      );
    });

    it("should revert if invalid user", async () => {
      await expectRevert.unspecified(
        pricerInstance.updateAcceptableMaturity(0, { from: accounts[1] })
      );
    });
  });
  describe("isAcceptable", function () {
    let currentTimestamp;
    let maturityTimestamp;
    beforeEach(async () => {
      const block = await web3.eth.getBlock("latest");
      currentTimestamp = block.timestamp;
      maturityTimestamp = currentTimestamp + 100000;
      await pricerInstance.updateAcceptableMaturity(maturityTimestamp);
    });
    it("should revert already expired bond", async function () {
      await expectRevert.unspecified(
        pricerInstance.isAcceptable(ETHPrice, Vol, -1)
      );
    });
    it("should revert bond whose maturity is after aggregator's maturity", async function () {
      await expectRevert.unspecified(
        pricerInstance.isAcceptable(ETHPrice, Vol, 100001)
      );
    });
    it("accept valid bond #1", async function () {
      await pricerInstance.isAcceptable(ETHPrice, Vol, 100000 - 40);
    });
    it("accept valid bond #2", async function () {
      await pricerInstance.isAcceptable(ETHPrice, Vol, 0);
    });
  });
});
