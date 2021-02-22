// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "../util/TransferETHInterface.sol";
import "../../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface BondTokenInterface is IERC20 {
    event LogExpire(uint128 rateNumerator, uint128 rateDenominator, bool firstTime);

    function mint(address account, uint256 amount) external returns (bool success);

    function expire(uint128 rateNumerator, uint128 rateDenominator)
        external
        returns (bool firstTime);

    function simpleBurn(address account, uint256 amount) external returns (bool success);

    function burn(uint256 amount) external returns (bool success);

    function burnAll() external returns (uint256 amount);

    function getRate() external view returns (uint128 rateNumerator, uint128 rateDenominator);
}
