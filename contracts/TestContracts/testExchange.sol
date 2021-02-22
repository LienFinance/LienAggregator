// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;
import "../BondToken_and_GDOTC/util/TransferETH.sol";
import "../BondToken_and_GDOTC/bondPricer/BondPricerInterface.sol";
import "../BondToken_and_GDOTC/bondMaker/BondMakerInterface.sol";
import "../Interfaces/VolatilityOracleInterface.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestExchange is TransferETH {
    mapping(address => int16) AddressToSpread;
    struct VSBondPool {
        address bondMakerForUserAddress;
        address bondPricerForUserAddress;
        address bondPricerAddress;
        int16 feeBaseE4;
    }

    mapping(bytes32 => VSBondPool) bondPools;

    struct VSEthPool {
        address ethOracleAddress;
        address bondPricerAddress;
        int16 feeBaseE4;
        bool isBondSale;
    }

    mapping(bytes32 => VSEthPool) ethPools;

    mapping(address => uint256) ethDeposits;

    struct VSERC20Pool {
        address oracleAddress;
        address bondPricerAddress;
        address tokenAddress;
        int16 feeBaseE4;
        bool isBondSale;
    }
    mapping(bytes32 => VSERC20Pool) erc20Pools;
    BondMakerInterface bondMaker;

    constructor(BondMakerInterface _bondMaker) {
        bondMaker = _bondMaker;
    }

    function bondMakerAddress() external view returns (BondMakerInterface) {
        return bondMaker;
    }

    function setAggregator(address AggregatorAddress, int16 spread) public {
        AddressToSpread[AggregatorAddress] = spread;
    }

    function getSpread(address AggregatorAddress) public view returns (int16 spread) {
        return AddressToSpread[AggregatorAddress];
    }

    function withdrawEth() public {
        _transferETH(msg.sender, address(this).balance);
    }

    function ethAllowance(address) external view returns (uint256 amount) {
        return ethDeposits[msg.sender];
    }

    function depositEth() public payable {
        ethDeposits[msg.sender] = msg.value;
    }

    function createVsBondPool(
        BondMakerInterface bondMakerForUserAddress,
        VolatilityOracleInterface,
        BondPricerInterface bondPricerForUserAddress,
        BondPricerInterface bondPricerAddress,
        int16 feeBaseE4
    ) external returns (bytes32 poolID) {
        poolID = generateVsBondPoolID(msg.sender, address(bondMakerForUserAddress));

        bondPools[poolID].bondMakerForUserAddress = address(bondMakerForUserAddress);
        bondPools[poolID].bondPricerAddress = address(bondPricerAddress);
        bondPools[poolID].bondPricerForUserAddress = address(bondPricerForUserAddress);
        bondPools[poolID].feeBaseE4 = feeBaseE4;
    }

    function createVsErc20Pool(
        ERC20 swapPairAddress,
        LatestPriceOracleInterface swapPairOracleAddress,
        BondPricerInterface bondPricerAddress,
        int16 feeBaseE4,
        bool isBondSale
    ) external returns (bytes32 poolID) {
        poolID = generateVsErc20PoolID(msg.sender, address(swapPairAddress), isBondSale);
        erc20Pools[poolID].isBondSale = isBondSale;
        erc20Pools[poolID].bondPricerAddress = address(bondPricerAddress);
        erc20Pools[poolID].feeBaseE4 = feeBaseE4;
        erc20Pools[poolID].oracleAddress = address(swapPairOracleAddress);
        erc20Pools[poolID].tokenAddress = address(swapPairAddress);
    }

    function createVsEthPool(
        LatestPriceOracleInterface ethOracleAddress,
        BondPricerInterface bondPricerAddress,
        int16 feeBaseE4,
        bool isBondSale
    ) external returns (bytes32 poolID) {
        poolID = generateVsEthPoolID(msg.sender, isBondSale);
        ethPools[poolID].feeBaseE4 = feeBaseE4;
        ethPools[poolID].ethOracleAddress = address(ethOracleAddress);
        ethPools[poolID].bondPricerAddress = address(bondPricerAddress);
        ethPools[poolID].isBondSale = isBondSale;
    }

    function updateVsBondPool(
        bytes32 poolID,
        VolatilityOracleInterface,
        BondPricerInterface bondPricerForUserAddress,
        BondPricerInterface bondPricerAddress,
        int16 feeBaseE4
    ) external {
        bondPools[poolID].bondPricerAddress = address(bondPricerAddress);
        bondPools[poolID].bondPricerForUserAddress = address(bondPricerForUserAddress);
        bondPools[poolID].feeBaseE4 = feeBaseE4;
    }

    function updateVsErc20Pool(
        bytes32 poolID,
        LatestPriceOracleInterface swapPairOracleAddress,
        BondPricerInterface bondPricerAddress,
        int16 feeBaseE4
    ) external {
        erc20Pools[poolID].bondPricerAddress = address(bondPricerAddress);
        erc20Pools[poolID].feeBaseE4 = feeBaseE4;
        erc20Pools[poolID].oracleAddress = address(swapPairOracleAddress);
    }

    function updateVsEthPool(
        bytes32 poolID,
        LatestPriceOracleInterface ethOracleAddress,
        BondPricerInterface bondPricerAddress,
        int16 feeBaseE4
    ) external {
        ethPools[poolID].feeBaseE4 = feeBaseE4;
        ethPools[poolID].ethOracleAddress = address(ethOracleAddress);
        ethPools[poolID].bondPricerAddress = address(bondPricerAddress);
    }

    function getEthPoolData(bytes32 poolID)
        public
        view
        returns (
            address,
            address,
            int16,
            bool
        )
    {
        return (
            ethPools[poolID].ethOracleAddress,
            ethPools[poolID].bondPricerAddress,
            ethPools[poolID].feeBaseE4,
            ethPools[poolID].isBondSale
        );
    }

    function getErc20PoolData(bytes32 poolID)
        public
        view
        returns (
            address,
            address,
            address,
            int16,
            bool
        )
    {
        return (
            erc20Pools[poolID].oracleAddress,
            erc20Pools[poolID].bondPricerAddress,
            erc20Pools[poolID].tokenAddress,
            erc20Pools[poolID].feeBaseE4,
            erc20Pools[poolID].isBondSale
        );
    }

    function getBondPoolData(bytes32 poolID)
        public
        view
        returns (
            address,
            address,
            address,
            int16
        )
    {
        return (
            bondPools[poolID].bondMakerForUserAddress,
            bondPools[poolID].bondPricerForUserAddress,
            bondPools[poolID].bondPricerAddress,
            bondPools[poolID].feeBaseE4
        );
    }

    function generateVsEthPoolID(address seller, bool isBondSale)
        public
        pure
        returns (bytes32 poolID)
    {
        return keccak256(abi.encode(seller, 100, isBondSale));
    }

    function generateVsBondPoolID(address seller, address bondMakerForUser)
        public
        pure
        returns (bytes32 poolID)
    {
        return keccak256(abi.encode(seller, bondMakerForUser, 100));
    }

    function generateVsErc20PoolID(
        address seller,
        address swapPairAddress,
        bool isBondSale
    ) public pure returns (bytes32 poolID) {
        return keccak256(abi.encode(seller, swapPairAddress, isBondSale));
    }
}
