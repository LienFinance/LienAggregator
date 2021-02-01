// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "../BondToken_and_GDOTC/util/TransferETH.sol";
import "../Interfaces/StrategyInterface.sol";
import "../BondToken_and_GDOTC/bondMaker/BondMakerInterface.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestAggregator2 is TransferETH {
    uint256 public amount;
    address public SBTAddress;
    uint256 receiveAmount;

    function removeAfterMaturity() external returns (uint256 ethAmount) {
        uint256 value = receiveAmount;
        if (receiveAmount == 0) {
            value = address(this).balance;
        }
        _transferETH(msg.sender, value);
        return value;
    }

    function addLiquidity() external payable {
        receiveAmount = msg.value;
    }

    function setSBTAddress(address _SBTAddress) public {
        SBTAddress = _SBTAddress;
    }
}

contract MockSimpleAggregator {
    address collateralAddress;
    uint256 collateralAmount;
    int16 collateralDecimal;

    function getCollateralAddress() external view returns (address) {
        return collateralAddress;
    }

    function getCollateralAmount() public view returns (uint256) {
        return collateralAmount;
    }

    function getCollateralDecimal() public view returns (int16) {
        return collateralDecimal;
    }

    function changeData(
        address _collateralAddress,
        uint256 _collateralAmount,
        int16 _collateralDecimal
    ) external {
        collateralAddress = _collateralAddress;
        collateralAmount = _collateralAmount;
        collateralDecimal = _collateralDecimal;
    }

    function transferToken(IERC20 token, uint256 amount) public {
        token.transfer(msg.sender, amount);
    }
    /*
  function getTrancheBonds(
    address strategyAddress,
    BondMakerInterface bondMaker,
    address aggregatorAddress,
    uint256 price,
    uint256[] calldata bondGroupList
  ) external view returns (int256[] memory bonds) {
      return SimpleStrategyInterface(strategyAddress).
  getTrancheBonds(
    bondMaker,
     aggregatorAddress,
    price,
    bondGroupList
  );
  */
}
