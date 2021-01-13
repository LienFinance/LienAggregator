// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;
import "./VolatilityOracleInterface.sol";
import "./BondPricerInterface.sol";
import "./BondMakerInterface.sol";
import "./LatestPriceOracleInterface.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface ExchangeInterface {
    function changeSpread(int16 spread) external;

    function createVsBondPool(
        BondMakerInterface bondMakerForUserAddress,
        VolatilityOracleInterface volatilityOracleAddress,
        BondPricerInterface bondPricerForUserAddress,
        BondPricerInterface bondPricerAddress,
        int16 feeBaseE4
    ) external returns (bytes32 poolID);

    function createVsErc20Pool(
        ERC20 swapPairAddress,
        LatestPriceOracleInterface swapPairOracleAddress,
        BondPricerInterface bondPricerAddress,
        int16 feeBaseE4,
        bool isBondSale
    ) external returns (bytes32 poolID);

    function createVsEthPool(
        LatestPriceOracleInterface ethOracleAddress,
        BondPricerInterface bondPricerAddress,
        int16 feeBaseE4,
        bool isBondSale
    ) external returns (bytes32 poolID);

    function updateVsBondPool(
        bytes32 poolID,
        VolatilityOracleInterface volatilityOracleAddress,
        BondPricerInterface bondPricerForUserAddress,
        BondPricerInterface bondPricerAddress,
        int16 feeBaseE4
    ) external;

    function updateVsErc20Pool(
        bytes32 poolID,
        LatestPriceOracleInterface swapPairOracleAddress,
        BondPricerInterface bondPricerAddress,
        int16 feeBaseE4
    ) external;

    function updateVsEthPool(
        bytes32 poolID,
        LatestPriceOracleInterface ethOracleAddress,
        BondPricerInterface bondPricerAddress,
        int16 feeBaseE4
    ) external;

    function generateVsBondPoolID(address seller, address bondMakerForUser)
        external
        view
        returns (bytes32 poolID);

    function generateVsErc20PoolID(
        address seller,
        address swapPairAddress,
        bool isBondSale
    ) external view returns (bytes32 poolID);

    function generateVsEthPoolID(address seller, bool isBondSale)
        external
        view
        returns (bytes32 poolID);

    function withdrawEth() external;

    function depositEth() external payable;

    function ethAllowance(address owner) external view returns (uint256 amount);
}
