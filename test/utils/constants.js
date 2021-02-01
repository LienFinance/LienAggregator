// General
const multiplyer = 10 ** 8;
const volatility = 10 ** 7;

// ETH
const sbtPoint_ETH = [
  0,
  0,
  200 * multiplyer,
  200 * multiplyer,
  200 * multiplyer,
  200 * multiplyer,
  200 * multiplyer * 2,
  200 * multiplyer,
];
const callPoint_ETH = [
  0,
  0,
  400 * multiplyer,
  0,
  400 * multiplyer,
  0,
  400 * multiplyer * 2,
  400 * multiplyer,
];

const lev2Point_ETH = [
  0,
  0,
  200 * multiplyer,
  0,
  200 * multiplyer,
  0,
  600 * multiplyer,
  200 * multiplyer,
  600 * multiplyer,
  200 * multiplyer,
  800 * multiplyer,
  200 * multiplyer,
];

const volShortPoint_ETH = [
  0,
  0,
  200 * multiplyer,
  0,

  200 * multiplyer,
  0,
  400 * multiplyer,
  100 * multiplyer,

  400 * multiplyer,
  100 * multiplyer,
  600 * multiplyer,
  0,

  600 * multiplyer,
  0,
  800 * multiplyer,
  0,
];

const sbtSp_ETH = 200 * multiplyer;
const baseSbtPoint_ETH = [
  0,
  0,
  sbtSp_ETH,
  sbtSp_ETH,
  sbtSp_ETH,
  sbtSp_ETH,
  sbtSp_ETH * 2,
  sbtSp_ETH,
];
const baseCallPoint_ETH = [
  0,
  0,
  sbtSp_ETH,
  0,
  sbtSp_ETH,
  0,
  sbtSp_ETH * 2,
  sbtSp_ETH,
];

// ERC20
const mvs_ERC20 = 62500;
const sbtSp_ERC20 = 125000;
const callSp_ERC20 = 250000;
const lev2Sp_ERC20 = 375000;

const baseSbtPoint_ERC20 = [
  0,
  0,
  sbtSp_ERC20,
  sbtSp_ERC20,
  sbtSp_ERC20,
  sbtSp_ERC20,
  sbtSp_ERC20 * 2,
  sbtSp_ERC20,
];
const baseCallPoint_ERC20 = [
  0,
  0,
  sbtSp_ERC20,
  0,
  sbtSp_ERC20,
  0,
  sbtSp_ERC20 * 2,
  sbtSp_ERC20,
];
const sbtPoint_ERC20 = [
  0,
  0,
  sbtSp_ERC20,
  sbtSp_ERC20,
  sbtSp_ERC20,
  sbtSp_ERC20,
  sbtSp_ERC20 * 2,
  sbtSp_ERC20,
];
const callPoint_ERC20 = [
  0,
  0,
  callSp_ERC20,
  0,
  callSp_ERC20,
  0,
  callSp_ERC20 * 2,
  callSp_ERC20,
];

const lev2Point_ERC20 = [
  0,
  0,
  sbtSp_ERC20,
  0,
  sbtSp_ERC20,
  0,
  lev2Sp_ERC20,
  sbtSp_ERC20,
  lev2Sp_ERC20,
  sbtSp_ERC20,
  lev2Sp_ERC20 + sbtSp_ERC20,
  sbtSp_ERC20,
];

const volShortPoint_ERC20 = [
  0,
  0,
  sbtSp_ERC20,
  0,
  sbtSp_ERC20,
  0,
  callSp_ERC20,
  mvs_ERC20,
  callSp_ERC20,
  mvs_ERC20,
  lev2Sp_ERC20,
  0,
  lev2Sp_ERC20,
  0,
  lev2Sp_ERC20 + sbtSp_ERC20,
  0,
];

const testCaseETH = {
  untilMaturity: 0.1,
  strikePriceSBT: 200,
  strikePriceCall: 400,
  Lev2EndPoint: 600,
};

const testCaseERC20 = {
  untilMaturity: 0.1,
  strikePriceSBT: 0.00125,
  strikePriceCall: 0.0025,
  Lev2EndPoint: 0.00375,
};

module.exports = {
  multiplyer: multiplyer,
  volatility: volatility,

  sbtPoint_ETH: sbtPoint_ETH,
  sbtPoint_ERC20: sbtPoint_ERC20,
  callPoint_ETH: callPoint_ETH,
  callPoint_ERC20: callPoint_ERC20,
  lev2Point_ETH: lev2Point_ETH,
  lev2Point_ERC20: lev2Point_ERC20,
  volShortPoint_ETH: volShortPoint_ETH,
  volShortPoint_ERC20: volShortPoint_ERC20,

  baseSbtPoint_ETH: baseSbtPoint_ETH,
  baseSbtPoint_ERC20: baseSbtPoint_ERC20,
  baseCallPoint_ETH: baseCallPoint_ETH,
  baseCallPoint_ERC20: baseCallPoint_ERC20,

  sbtSp_ETH: sbtSp_ETH,
  mvs_ERC20: mvs_ERC20,
  sbtSp_ERC20: sbtSp_ERC20,
  callSp_ERC20: callSp_ERC20,
  lev2Sp_ERC20: lev2Sp_ERC20,

  testCaseETH: testCaseETH,
  testCaseERC20: testCaseERC20,
};
