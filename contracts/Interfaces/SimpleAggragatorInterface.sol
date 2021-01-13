// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

interface SimpleAggregatorInterface {
    function addIssuableBondGroup(uint256 bondGroupId) external;

    function renewMaturity() external;

    function removeLiquidity(uint128 amount) external returns (bool success);

    function settleTokens()
        external
        returns (uint256 unsentETH, uint256 unsentToken);

    function addIssuableBondGroups(uint256[] memory bondGroupIds) external;

    function liquidateBonds() external;

    function trancheBonds() external;

    function isEthAggregator() external pure returns (bool);

    function getCollateralAmount() external view returns (uint256);

    function getCollateralDecimal() external view returns (int16);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function transfer(address _to, uint256 _value)
        external
        returns (bool success);

    function balanceOf(address _owner) external view returns (uint256 balance);

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool success);

    function approve(address _spender, uint256 _value)
        external
        returns (bool success);

    function allowance(address _owner, address _spender)
        external
        view
        returns (uint256 remaining);
}
