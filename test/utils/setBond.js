const BT = artifacts.require("testBondToken");
const { time } = require("@openzeppelin/test-helpers");
const ZAddress = "0x0000000000000000000000000000000000000000";
let registerBondGroup2 = async function (
  testCase,
  maturity,
  bondMakerInstance,
  generatorInstance,
  SBTID
) {
  const priceMultiplyer = 10 ** 8;
  const incline =
    (testCase.strikePriceCall - testCase.strikePriceSBT) /
    (testCase.Lev2EndPoint - testCase.strikePriceSBT);

  const Lev2ValueInCallSP = Math.floor(
    (((testCase.strikePriceCall - testCase.strikePriceSBT) *
      (testCase.strikePriceCall - testCase.strikePriceSBT)) /
      (testCase.Lev2EndPoint - testCase.strikePriceSBT)) *
      priceMultiplyer
  );

  const maxProfitVolShort =
    (testCase.strikePriceCall - testCase.strikePriceSBT) * priceMultiplyer -
    Lev2ValueInCallSP;

  const CallFnMapID = await generatorInstance.getFnMap([
    0,
    0,
    testCase.strikePriceCall * priceMultiplyer,
    0,
    testCase.strikePriceCall * priceMultiplyer,
    0,
    testCase.strikePriceCall * priceMultiplyer * 2,
    testCase.strikePriceCall * priceMultiplyer,
  ]);
  receipt = await bondMakerInstance.registerNewBond(maturity, CallFnMapID);
  const CallID = receipt.logs[0].args.bondID;

  const Lev2FnMapID = await generatorInstance.getFnMap([
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
  receipt = await bondMakerInstance.registerNewBond(maturity, Lev2FnMapID);
  const Lev2ID = receipt.logs[0].args.bondID;

  const VolSFnMapID = await generatorInstance.getFnMap([
    0,
    0,
    testCase.strikePriceSBT * priceMultiplyer,
    0,

    testCase.strikePriceSBT * priceMultiplyer,
    0,
    testCase.strikePriceCall * priceMultiplyer,
    maxProfitVolShort,

    testCase.strikePriceCall * priceMultiplyer,
    maxProfitVolShort,
    testCase.Lev2EndPoint * priceMultiplyer,
    0,

    testCase.Lev2EndPoint * priceMultiplyer,
    0,
    testCase.Lev2EndPoint * priceMultiplyer * 2,
    0,
  ]);
  receipt = await bondMakerInstance.registerNewBond(maturity, VolSFnMapID);
  const VolSID = receipt.logs[0].args.bondID;
  if (SBTID == undefined) {
    const SBTFnMapID = await generatorInstance.getFnMap([
      0,
      0,
      testCase.strikePriceSBT * priceMultiplyer,
      testCase.strikePriceSBT * priceMultiplyer,
      testCase.strikePriceSBT * priceMultiplyer,
      testCase.strikePriceSBT * priceMultiplyer,
      testCase.strikePriceSBT * priceMultiplyer * 2,
      testCase.strikePriceSBT * priceMultiplyer,
    ]);

    let receipt = await bondMakerInstance.registerNewBond(maturity, SBTFnMapID);
    SBTID = receipt.logs[0].args.bondID;

    const LBTFnMapID = await generatorInstance.getFnMap([
      0,
      0,
      testCase.strikePriceSBT * priceMultiplyer,
      0,
      testCase.strikePriceSBT * priceMultiplyer,
      0,
      testCase.strikePriceSBT * priceMultiplyer * 2,
      testCase.strikePriceSBT * priceMultiplyer,
    ]);
    receipt = await bondMakerInstance.registerNewBond(maturity, LBTFnMapID);
    const LBTID = receipt.logs[0].args.bondID;
    await bondMakerInstance.registerNewBondGroup([SBTID, LBTID], maturity);

    await bondMakerInstance.registerNewBondGroup(
      [SBTID, CallID, Lev2ID, VolSID],
      maturity
    );
  } else {
    await bondMakerInstance.registerNewBondGroup(
      [SBTID, CallID, Lev2ID, VolSID],
      maturity
    );
  }
  return { SBTID, CallID, Lev2ID, VolSID };
};

let addIssuable = async function (
  testCase,
  aggregatorInstance,
  oracleInstance,
  bondIndex
) {
  for (let i = 0; i < testCase.bonds.length; i++) {
    console.log(i);
    await aggregatorInstance.addIssuableBondGroup(
      bondIndex + i - (testCase.bonds.length - 1)
    );
  }
};

let registerTrancheBonds2 = async function (
  testCase,
  maturity,
  bondMakerInstance,
  oracleInstance,
  aggregatorInstance,
  accounts,
  generatorInstance,
  isTrueAggregator,
  collateralAddress,
  SBTID = undefined
) {
  /*
  if (aggregatorAddress != accounts[1]) {
    aggregatorInstance = await Aggregator.at(aggregatorAddress);
  }
  */
  if (testCase.ethAmount > 0 && isTrueAggregator) {
    await aggregatorInstance.sendTransaction({
      from: accounts[0],
      value: web3.utils.toWei(String(testCase.ethAmount), "ether"),
    });
  }
  let bondIndex = 0;
  await time.increaseTo(maturity.toNumber() - 100000);
  for (let i = 0; i < testCase.bonds.length; i++) {
    const bondIDs = await registerBondGroup2(
      testCase.bonds[i],
      maturity,
      bondMakerInstance,
      generatorInstance,
      SBTID
    );
    const nextBondIndex = await bondMakerInstance.nextBondGroupID();
    bondIndex = nextBondIndex.toNumber() - 1;
    SBTID = bondIDs.SBTID;
    if (testCase.amounts[i] > 0) {
      await bondMakerInstance.issueNewBonds(bondIndex, {
        value: testCase.amounts[i] * 10 ** 10,
        from: accounts[1],
      });
    }
    //if (isTrueAggregator) {
    const bgInfo = await bondMakerInstance.getBondGroup(bondIndex);
    for (let bondID of bgInfo[0]) {
      const bondInfo = await bondMakerInstance.getBond(bondID);
      const bondInstance = await BT.at(bondInfo[0]);
      const balance = await bondInstance.balanceOf(accounts[1]);
      await bondInstance.transfer(aggregatorInstance.address, balance, {
        from: accounts[1],
      });
      //}
    }
  }
  if (isTrueAggregator) {
    await addIssuable(testCase, aggregatorInstance, oracleInstance, bondIndex);
  } else {
    await aggregatorInstance.changeData(
      collateralAddress,
      testCase.baseAmount * 10 ** 10,
      18
    );
  }
  return SBTID;
};

let registerTrancheBondsERC20 = async function (
  testCase,
  maturity,
  bondMakerInstance,
  oracleInstance,
  aggregatorInstance,
  accounts,
  generatorInstance,
  isTrueAggregator,
  collateralInstance,
  decimal,
  SBTID = undefined
) {
  /*
  if (aggregatorAddress != accounts[1]) {
    aggregatorInstance = await Aggregator.at(aggregatorAddress);
  }
  */
  if (testCase.ethAmount > 0 && isTrueAggregator) {
    await collateralInstance.transfer(
      aggregatorInstance.address,
      testCase.ethAmount * 10 ** decimal
    );
  }
  let bondIndex = 0;
  await time.increaseTo(maturity.toNumber() - 100000);
  for (let i = 0; i < testCase.bonds.length; i++) {
    const bondIDs = await registerBondGroup2(
      testCase.bonds[i],
      maturity,
      bondMakerInstance,
      generatorInstance,
      SBTID
    );
    const nextBondIndex = await bondMakerInstance.nextBondGroupID();
    bondIndex = nextBondIndex.toNumber() - 1;
    SBTID = bondIDs.SBTID;
    if (testCase.amounts[i] > 0) {
      await bondMakerInstance.issueNewBonds(bondIndex, testCase.amounts[i], {
        from: accounts[0],
      });
    }
    //if (isTrueAggregator) {
    const bgInfo = await bondMakerInstance.getBondGroup(bondIndex);
    for (let bondID of bgInfo[0]) {
      const bondInfo = await bondMakerInstance.getBond(bondID);
      const bondInstance = await BT.at(bondInfo[0]);
      const balance = await bondInstance.balanceOf(accounts[0]);
      await bondInstance.transfer(aggregatorInstance.address, balance, {
        from: accounts[0],
      });
      //}
    }
  }
  if (isTrueAggregator) {
    await addIssuable(testCase, aggregatorInstance, oracleInstance, bondIndex);
  } else {
    await aggregatorInstance.changeData(
      collateralInstance.address,
      testCase.baseAmount,
      8
    );
  }
  return SBTID;
};

async function registerBondGroup(testCase, maturity, bondMakerInstance) {
  const priceMultiplyer = 10 ** 8;
  const maxProfitVolShort =
    ((testCase.strikePriceCall - testCase.strikePriceSBT) *
      (testCase.strikePriceCall - testCase.Lev2EndPoint)) /
    (testCase.strikePriceSBT - testCase.Lev2EndPoint);
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
    Math.floor(maxProfitVolShort * priceMultiplyer),
    testCase.strikePriceCall * priceMultiplyer,
    Math.floor(maxProfitVolShort * priceMultiplyer),
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
  return { SBTFnMapID, LBTFnMapID, Lev2FnMapID, VolSFnMapID };
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

  await aggregatorInstance.changeData(
    ZAddress,
    testCase.baseAmount * 10 ** 10,
    18
  );
}

async function calcMaturity() {
  const block = await web3.eth.getBlock("latest");
  const timestamp = block.timestamp;
  const weeks = Math.floor((timestamp - 144000) / 604800);
  return (Number(weeks) + 3) * 604800 + 144000;
}

module.exports = {
  registerBondGroup: registerBondGroup,
  registerTrancheBonds: registerTrancheBonds,
  registerBondGroupForRBM: registerBondGroup2,
  registerTrancheBondsForRBM: registerTrancheBonds2,
  registerTrancheBondsERC20: registerTrancheBondsERC20,
  calcMaturity: calcMaturity,
};
