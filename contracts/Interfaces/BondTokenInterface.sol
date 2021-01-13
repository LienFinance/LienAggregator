// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;
import "../utils/ERC20Interface.sol";

interface BondTokenInterface is ERC20Interface {
    event LogExpire(
        uint128 rateNumerator,
        uint128 rateDenominator,
        bool firstTime
    );

    function mint(address account, uint256 amount)
        external
        returns (bool success);

    function expire(uint128 rateNumerator, uint128 rateDenominator)
        external
        returns (bool firstTime);

    function burn(uint256 amount) external returns (bool success);

    function burnAll() external returns (uint256 amount);

    function owner() external view returns (address);

    function getRate()
        external
        view
        returns (uint128 rateNumerator, uint128 rateDenominator);
}
