// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./BondExchange.sol";
import "../../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

abstract contract BondVsErc20Exchange is BondExchange {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    struct VsErc20Pool {
        address seller;
        ERC20 swapPairToken;
        LatestPriceOracleInterface swapPairOracle;
        BondPricerInterface bondPricer;
        int16 feeBaseE4;
        bool isBondSale;
    }
    mapping(bytes32 => VsErc20Pool) internal _vsErc20Pool;

    event LogCreateErc20ToBondPool(
        bytes32 indexed poolID,
        address indexed seller,
        address indexed swapPairAddress
    );

    event LogCreateBondToErc20Pool(
        bytes32 indexed poolID,
        address indexed seller,
        address indexed swapPairAddress
    );

    event LogUpdateVsErc20Pool(
        bytes32 indexed poolID,
        address swapPairOracleAddress,
        address bondPricerAddress,
        int16 feeBase // decimal: 4
    );

    event LogDeleteVsErc20Pool(bytes32 indexed poolID);

    event LogExchangeErc20ToBond(
        address indexed buyer,
        bytes32 indexed bondID,
        bytes32 indexed poolID,
        uint256 bondAmount, // decimal: 8
        uint256 swapPairAmount, // decimal: ERC20.decimals()
        uint256 volume // USD, decimal: 8
    );

    event LogExchangeBondToErc20(
        address indexed buyer,
        bytes32 indexed bondID,
        bytes32 indexed poolID,
        uint256 bondAmount, // decimal: 8
        uint256 swapPairAmount, // decimal: ERC20.decimals()
        uint256 volume // USD, decimal: 8
    );

    /**
     * @dev Reverts when the pool ID does not exist.
     */
    modifier isExsistentVsErc20Pool(bytes32 poolID) {
        require(_vsErc20Pool[poolID].seller != address(0), "the exchange pair does not exist");
        _;
    }

    /**
     * @notice Exchange buyer's ERC20 token to the seller's bond.
     * @dev Ensure the seller has approved sufficient bonds and
     * you approve ERC20 token to pay before executing this function.
     * @param bondID is the target bond ID.
     * @param poolID is the target pool ID.
     * @param swapPairAmount is the exchange pair token amount to pay.
     * @param expectedAmount is the bond amount to receive.
     * @param range (decimal: 3)
     */
    function exchangeErc20ToBond(
        bytes32 bondID,
        bytes32 poolID,
        uint256 swapPairAmount,
        uint256 expectedAmount,
        uint256 range
    ) external returns (uint256 bondAmount) {
        bondAmount = _exchangeErc20ToBond(msg.sender, bondID, poolID, swapPairAmount);
        // assert(bondAmount != 0);
        _assertExpectedPriceRange(bondAmount, expectedAmount, range);
    }

    /**
     * @notice Exchange buyer's bond to the seller's ERC20 token.
     * @dev Ensure the seller has approved sufficient ERC20 token and
     * you approve bonds to pay before executing this function.
     * @param bondID is the target bond ID.
     * @param poolID is the target pool ID.
     * @param bondAmount is the bond amount to pay.
     * @param expectedAmount is the exchange pair token amount to receive.
     * @param range (decimal: 3)
     */
    function exchangeBondToErc20(
        bytes32 bondID,
        bytes32 poolID,
        uint256 bondAmount,
        uint256 expectedAmount,
        uint256 range
    ) external returns (uint256 swapPairAmount) {
        swapPairAmount = _exchangeBondToErc20(msg.sender, bondID, poolID, bondAmount);
        // assert(swapPairAmount != 0);
        _assertExpectedPriceRange(swapPairAmount, expectedAmount, range);
    }

    /**
     * @notice Returns the exchange rate including spread.
     */
    function calcRateBondToErc20(bytes32 bondID, bytes32 poolID) external returns (uint256 rateE8) {
        (rateE8, , , ) = _calcRateBondToErc20(bondID, poolID);
    }

    /**
     * @notice Returns pool ID generated by the immutable pool settings.
     */
    function generateVsErc20PoolID(
        address seller,
        address swapPairAddress,
        bool isBondSale
    ) external view returns (bytes32 poolID) {
        return _generateVsErc20PoolID(seller, swapPairAddress, isBondSale);
    }

    /**
     * @notice Register a new vsErc20Pool.
     */
    function createVsErc20Pool(
        ERC20 swapPairAddress,
        LatestPriceOracleInterface swapPairOracleAddress,
        BondPricerInterface bondPricerAddress,
        int16 feeBaseE4,
        bool isBondSale
    ) external returns (bytes32 poolID) {
        return
            _createVsErc20Pool(
                msg.sender,
                swapPairAddress,
                swapPairOracleAddress,
                bondPricerAddress,
                feeBaseE4,
                isBondSale
            );
    }

    /**
     * @notice Update the mutable pool settings.
     */
    function updateVsErc20Pool(
        bytes32 poolID,
        LatestPriceOracleInterface swapPairOracleAddress,
        BondPricerInterface bondPricerAddress,
        int16 feeBaseE4
    ) external {
        require(_vsErc20Pool[poolID].seller == msg.sender, "not the owner of the pool ID");

        _updateVsErc20Pool(poolID, swapPairOracleAddress, bondPricerAddress, feeBaseE4);
    }

    /**
     * @notice Delete the pool settings.
     */
    function deleteVsErc20Pool(bytes32 poolID) external {
        require(_vsErc20Pool[poolID].seller == msg.sender, "not the owner of the pool ID");

        _deleteVsErc20Pool(poolID);
    }

    /**
     * @notice Returns the pool settings.
     */
    function getVsErc20Pool(bytes32 poolID)
        external
        view
        returns (
            address seller,
            ERC20 swapPairAddress,
            LatestPriceOracleInterface swapPairOracleAddress,
            BondPricerInterface bondPricerAddress,
            int16 feeBaseE4,
            bool isBondSale
        )
    {
        return _getVsErc20Pool(poolID);
    }

    /**
     * @dev Exchange buyer's ERC20 token to the seller's bond.
     * Ensure the seller has approved sufficient bonds and
     * buyer approve ERC20 token to pay before executing this function.
     * @param buyer is the buyer address.
     * @param bondID is the target bond ID.
     * @param poolID is the target pool ID.
     * @param swapPairAmount is the exchange pair token amount to pay.
     * @return bondAmount is the received bond amount.
     */
    function _exchangeErc20ToBond(
        address buyer,
        bytes32 bondID,
        bytes32 poolID,
        uint256 swapPairAmount
    ) internal returns (uint256 bondAmount) {
        (address seller, ERC20 swapPairToken, , , , bool isBondSale) = _getVsErc20Pool(poolID);
        require(isBondSale, "This pool is for buying bond");

        (ERC20 bondToken, , , ) = _getBond(_bondMakerContract, bondID);
        require(address(bondToken) != address(0), "the bond is not registered");

        uint256 volumeE8;
        {
            (uint256 rateE8, , uint256 swapPairPriceE8, ) = _calcRateBondToErc20(bondID, poolID);
            require(rateE8 > MIN_EXCHANGE_RATE_E8, "exchange rate is too small");
            require(rateE8 < MAX_EXCHANGE_RATE_E8, "exchange rate is too large");
            uint8 decimalsOfSwapPair = swapPairToken.decimals();
            bondAmount =
                _applyDecimalGap(swapPairAmount, decimalsOfSwapPair, DECIMALS_OF_BOND + 8) /
                rateE8;
            require(bondAmount != 0, "must transfer non-zero bond amount");
            volumeE8 = swapPairPriceE8.mul(swapPairAmount).div(10**uint256(decimalsOfSwapPair));
        }

        require(bondToken.transferFrom(seller, buyer, bondAmount), "fail to transfer bonds");
        swapPairToken.safeTransferFrom(buyer, seller, swapPairAmount);

        emit LogExchangeErc20ToBond(buyer, bondID, poolID, bondAmount, swapPairAmount, volumeE8);
    }

    /**
     * @dev Exchange buyer's bond to the seller's ERC20 token.
     * Ensure the seller has approved sufficient ERC20 token and
     * buyer approve bonds to pay before executing this function.
     * @param buyer is the buyer address.
     * @param bondID is the target bond ID.
     * @param poolID is the target pool ID.
     * @param bondAmount is the bond amount to pay.
     * @return swapPairAmount is the received swap pair token amount.
     */
    function _exchangeBondToErc20(
        address buyer,
        bytes32 bondID,
        bytes32 poolID,
        uint256 bondAmount
    ) internal returns (uint256 swapPairAmount) {
        (address seller, ERC20 swapPairToken, , , , bool isBondSale) = _getVsErc20Pool(poolID);
        require(!isBondSale, "This pool is not for buying bond");

        (ERC20 bondToken, , , ) = _getBond(_bondMakerContract, bondID);
        require(address(bondToken) != address(0), "the bond is not registered");

        uint256 volumeE8;
        {
            (uint256 rateE8, uint256 bondPriceE8, , ) = _calcRateBondToErc20(bondID, poolID);
            require(rateE8 > MIN_EXCHANGE_RATE_E8, "exchange rate is too small");
            require(rateE8 < MAX_EXCHANGE_RATE_E8, "exchange rate is too large");
            uint8 decimalsOfSwapPair = swapPairToken.decimals();
            swapPairAmount = _applyDecimalGap(
                bondAmount.mul(rateE8),
                DECIMALS_OF_BOND + 8,
                decimalsOfSwapPair
            );
            require(swapPairAmount != 0, "must transfer non-zero token amount");
            volumeE8 = bondPriceE8.mul(bondAmount).div(10**uint256(DECIMALS_OF_BOND));
        }

        require(bondToken.transferFrom(buyer, seller, bondAmount), "fail to transfer bonds");
        swapPairToken.safeTransferFrom(seller, buyer, swapPairAmount);

        emit LogExchangeBondToErc20(buyer, bondID, poolID, bondAmount, swapPairAmount, volumeE8);
    }

    function _calcRateBondToErc20(bytes32 bondID, bytes32 poolID)
        internal
        returns (
            uint256 rateE8,
            uint256 bondPriceE8,
            uint256 swapPairPriceE8,
            int256 spreadE8
        )
    {
        (
            ,
            ,
            LatestPriceOracleInterface erc20Oracle,
            BondPricerInterface bondPricer,
            int16 feeBaseE4,
            bool isBondSale
        ) = _getVsErc20Pool(poolID);
        swapPairPriceE8 = _getLatestPrice(erc20Oracle);
        (bondPriceE8, spreadE8) = _calcBondPriceAndSpread(bondPricer, bondID, feeBaseE4);
        bondPriceE8 = _calcUsdPrice(bondPriceE8);
        rateE8 = bondPriceE8.mul(10**8).div(swapPairPriceE8, "ERC20 oracle price must be non-zero");

        // `spreadE8` is less than 0.15 * 10**8.
        if (isBondSale) {
            rateE8 = rateE8.mul(uint256(10**8 + spreadE8)) / 10**8;
        } else {
            rateE8 = rateE8.mul(10**8) / uint256(10**8 + spreadE8);
        }
    }

    function _generateVsErc20PoolID(
        address seller,
        address swapPairAddress,
        bool isBondSale
    ) internal view returns (bytes32 poolID) {
        return
            keccak256(
                abi.encode(
                    "Bond vs ERC20 exchange",
                    address(this),
                    seller,
                    swapPairAddress,
                    isBondSale
                )
            );
    }

    function _setVsErc20Pool(
        bytes32 poolID,
        address seller,
        ERC20 swapPairToken,
        LatestPriceOracleInterface swapPairOracle,
        BondPricerInterface bondPricer,
        int16 feeBaseE4,
        bool isBondSale
    ) internal {
        require(seller != address(0), "the pool ID already exists");
        require(address(swapPairToken) != address(0), "swapPairToken should be non-zero address");
        require(address(swapPairOracle) != address(0), "swapPairOracle should be non-zero address");
        require(address(bondPricer) != address(0), "bondPricer should be non-zero address");
        _vsErc20Pool[poolID] = VsErc20Pool({
            seller: seller,
            swapPairToken: swapPairToken,
            swapPairOracle: swapPairOracle,
            bondPricer: bondPricer,
            feeBaseE4: feeBaseE4,
            isBondSale: isBondSale
        });
    }

    function _createVsErc20Pool(
        address seller,
        ERC20 swapPairToken,
        LatestPriceOracleInterface swapPairOracle,
        BondPricerInterface bondPricer,
        int16 feeBaseE4,
        bool isBondSale
    ) internal returns (bytes32 poolID) {
        poolID = _generateVsErc20PoolID(seller, address(swapPairToken), isBondSale);
        require(_vsErc20Pool[poolID].seller == address(0), "the pool ID already exists");

        {
            uint256 price = _getLatestPrice(swapPairOracle);
            require(
                price != 0,
                "swapPairOracle has latestPrice() function which returns non-zero value"
            );
        }

        _setVsErc20Pool(
            poolID,
            seller,
            swapPairToken,
            swapPairOracle,
            bondPricer,
            feeBaseE4,
            isBondSale
        );

        if (isBondSale) {
            emit LogCreateErc20ToBondPool(poolID, seller, address(swapPairToken));
        } else {
            emit LogCreateBondToErc20Pool(poolID, seller, address(swapPairToken));
        }

        emit LogUpdateVsErc20Pool(poolID, address(swapPairOracle), address(bondPricer), feeBaseE4);
    }

    function _updateVsErc20Pool(
        bytes32 poolID,
        LatestPriceOracleInterface swapPairOracle,
        BondPricerInterface bondPricer,
        int16 feeBaseE4
    ) internal isExsistentVsErc20Pool(poolID) {
        (address seller, ERC20 swapPairToken, , , , bool isBondSale) = _getVsErc20Pool(poolID);
        _setVsErc20Pool(
            poolID,
            seller,
            swapPairToken,
            swapPairOracle,
            bondPricer,
            feeBaseE4,
            isBondSale
        );

        emit LogUpdateVsErc20Pool(poolID, address(swapPairOracle), address(bondPricer), feeBaseE4);
    }

    function _deleteVsErc20Pool(bytes32 poolID) internal isExsistentVsErc20Pool(poolID) {
        delete _vsErc20Pool[poolID];

        emit LogDeleteVsErc20Pool(poolID);
    }

    function _getVsErc20Pool(bytes32 poolID)
        internal
        view
        isExsistentVsErc20Pool(poolID)
        returns (
            address seller,
            ERC20 swapPairToken,
            LatestPriceOracleInterface swapPairOracle,
            BondPricerInterface bondPricer,
            int16 feeBaseE4,
            bool isBondSale
        )
    {
        VsErc20Pool memory exchangePair = _vsErc20Pool[poolID];
        seller = exchangePair.seller;
        swapPairToken = exchangePair.swapPairToken;
        swapPairOracle = exchangePair.swapPairOracle;
        bondPricer = exchangePair.bondPricer;
        feeBaseE4 = exchangePair.feeBaseE4;
        isBondSale = exchangePair.isBondSale;
    }
}
