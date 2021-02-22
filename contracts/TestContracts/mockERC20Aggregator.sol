// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract mockERC20Aggregator {
    address public SBTAddress;
    uint256 receiveAmount;
    address collateralAddress;

    constructor(address _collateralAddress) {
        collateralAddress = _collateralAddress;
    }

    function removeAfterMaturity() external returns (uint256 ethAmount) {
        uint256 value = receiveAmount;
        if (receiveAmount == 0) {
            value = IERC20(collateralAddress).balanceOf(address(this));
        }
        IERC20(collateralAddress).transfer(msg.sender, value);
        return value;
    }

    function addLiquidity(uint256 issueAmount) external {
        require(
            IERC20(collateralAddress).transferFrom(msg.sender, address(this), issueAmount),
            "Test Aggregator: Token transferFrom"
        );
        receiveAmount = issueAmount;
    }

    function setSBTAddress(address _SBTAddress) public {
        SBTAddress = _SBTAddress;
    }
}
