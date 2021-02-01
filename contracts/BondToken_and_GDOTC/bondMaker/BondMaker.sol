// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "../math/UseSafeMath.sol";
import "./BondMakerCollateralizedErc20Interface.sol";
import "../util/Time.sol";
import "../bondToken/BondTokenFactory.sol";
import "../util/Polyline.sol";

abstract contract BondMaker is UseSafeMath, BondMakerInterface, Time, Polyline {
    using SafeMath for uint256;
    using SafeMathDivRoundUp for uint256;
    using SafeMath for uint64;

    uint8 internal immutable DECIMALS_OF_BOND;
    uint8 internal immutable DECIMALS_OF_ORACLE_PRICE;
    address internal immutable FEE_TAKER;
    uint256 internal immutable MATURITY_SCALE;
    PriceOracleInterface internal immutable _oracleContract;

    uint256 internal _nextBondGroupID = 1;

    /**
     * @dev The contents in this internal storage variable can be seen by getBond function.
     */
    struct BondInfo {
        uint256 maturity;
        BondTokenInterface contractInstance;
        uint64 strikePrice;
        bytes32 fnMapID;
    }
    mapping(bytes32 => BondInfo) internal _bonds;

    /**
     * @dev The contents in this internal storage variable can be seen by getFnMap function.
     */
    mapping(bytes32 => LineSegment[]) internal _registeredFnMap;

    /**
     * @dev The contents in this internal storage variable can be seen by getBondGroup function.
     */
    struct BondGroup {
        bytes32[] bondIDs;
        uint256 maturity;
    }
    mapping(uint256 => BondGroup) internal _bondGroupList;

    constructor(
        PriceOracleInterface oracleAddress,
        address feeTaker,
        uint256 maturityScale,
        uint8 decimalsOfBond,
        uint8 decimalsOfOraclePrice
    ) {
        require(
            address(oracleAddress) != address(0),
            "oracleAddress should be non-zero address"
        );
        _oracleContract = oracleAddress;
        require(
            decimalsOfBond < 19,
            "the decimals of bond must be less than 19"
        );
        DECIMALS_OF_BOND = decimalsOfBond;
        require(
            decimalsOfOraclePrice < 19,
            "the decimals of oracle price must be less than 19"
        );
        DECIMALS_OF_ORACLE_PRICE = decimalsOfOraclePrice;
        require(
            feeTaker != address(0),
            "the fee taker must be non-zero address"
        );
        FEE_TAKER = feeTaker;
        require(maturityScale != 0, "MATURITY_SCALE must be positive");
        MATURITY_SCALE = maturityScale;
    }

    /**
     * @notice Create bond token contract.
     * The name of this bond token is its bond ID.
     * @dev To convert bytes32 to string, encode its bond ID at first, then convert to string.
     * The symbol of any bond token with bond ID is either SBT or LBT;
     * As SBT is a special case of bond token, any bond token which does not match to the form of
     * SBT is defined as LBT.
     */
    function registerNewBond(uint256 maturity, bytes calldata fnMap)
        external
        virtual
        override
        returns (
            bytes32,
            address,
            bytes32
        )
    {
        _assertBeforeMaturity(maturity);
        require(
            maturity < _getBlockTimestampSec() + 365 days,
            "the maturity is too far"
        );
        require(
            maturity % MATURITY_SCALE == 0,
            "the maturity must be the multiple of MATURITY_SCALE"
        );

        bytes32 bondID = generateBondID(maturity, fnMap);

        // Check if the same form of bond is already registered.
        // Cannot detect if the bond is described in a different polyline while two are
        // mathematically equivalent.
        require(
            address(_bonds[bondID].contractInstance) == address(0),
            "the bond type has been already registered"
        );

        // Register function mapping if necessary.
        bytes32 fnMapID = generateFnMapID(fnMap);
        uint64 sbtStrikePrice;
        if (_registeredFnMap[fnMapID].length == 0) {
            uint256[] memory polyline = decodePolyline(fnMap);
            for (uint256 i = 0; i < polyline.length; i++) {
                _registeredFnMap[fnMapID].push(unzipLineSegment(polyline[i]));
            }

            LineSegment[] memory segments = _registeredFnMap[fnMapID];
            assertPolyline(segments);
            require(
                !_isBondWorthless(segments),
                "the bond is 0-value at any price"
            );
            sbtStrikePrice = _getSbtStrikePrice(segments);
        } else {
            LineSegment[] memory segments = _registeredFnMap[fnMapID];
            sbtStrikePrice = _getSbtStrikePrice(segments);
        }

        BondTokenInterface bondTokenContract =
            _createNewBondToken(maturity, fnMap);

        // Set bond info to storage.
        _bonds[bondID] = BondInfo({
            maturity: maturity,
            contractInstance: bondTokenContract,
            strikePrice: sbtStrikePrice,
            fnMapID: fnMapID
        });

        emit LogNewBond(bondID, address(bondTokenContract), maturity, fnMapID);

        return (bondID, address(bondTokenContract), fnMapID);
    }

    /**
     * @dev Count the number of the end points on x axis. In the case of a simple SBT/LBT split,
     * 3 for SBT plus 3 for LBT equals to 6.
     * In the case of SBT with the strike price 100, (x,y) = (0,0), (100,100), (200,100) defines
     * the form of SBT on the field.
     * In the case of LBT with the strike price 100, (x,y) = (0,0), (100,0), (200,100) defines
     * the form of LBT on the field.
     * Right hand side area of the last grid point is expanded on the last line to the infinity.
     * nextBreakPointIndex returns the number of unique points on x axis.
     * In the case of SBT and LBT with the strike price 100, x = 0,100,200 are the unique points
     * and the number is 3.
     */
    function _assertBondGroup(bytes32[] memory bondIDs, uint256 maturity)
        internal
        view
    {
        require(
            bondIDs.length >= 2,
            "the bond group should consist of 2 or more bonds"
        );

        uint256 numOfBreakPoints = 0;
        for (uint256 i = 0; i < bondIDs.length; i++) {
            BondInfo storage bond = _bonds[bondIDs[i]];
            require(
                bond.maturity == maturity,
                "the maturity of the bonds must be same"
            );
            LineSegment[] storage polyline = _registeredFnMap[bond.fnMapID];
            numOfBreakPoints = numOfBreakPoints.add(polyline.length);
        }

        uint256 nextBreakPointIndex = 0;
        uint64[] memory rateBreakPoints = new uint64[](numOfBreakPoints);
        for (uint256 i = 0; i < bondIDs.length; i++) {
            BondInfo storage bond = _bonds[bondIDs[i]];
            LineSegment[] storage segments = _registeredFnMap[bond.fnMapID];
            for (uint256 j = 0; j < segments.length; j++) {
                uint64 breakPoint = segments[j].right.x;
                bool ok = false;

                for (uint256 k = 0; k < nextBreakPointIndex; k++) {
                    if (rateBreakPoints[k] == breakPoint) {
                        ok = true;
                        break;
                    }
                }

                if (ok) {
                    continue;
                }

                rateBreakPoints[nextBreakPointIndex] = breakPoint;
                nextBreakPointIndex++;
            }
        }

        for (uint256 k = 0; k < rateBreakPoints.length; k++) {
            uint64 rate = rateBreakPoints[k];
            uint256 totalBondPriceN = 0;
            uint256 totalBondPriceD = 1;
            for (uint256 i = 0; i < bondIDs.length; i++) {
                BondInfo storage bond = _bonds[bondIDs[i]];
                LineSegment[] storage segments = _registeredFnMap[bond.fnMapID];
                (uint256 segmentIndex, bool ok) =
                    _correspondSegment(segments, rate);

                require(ok, "invalid domain expression");

                (uint128 n, uint64 d) = _mapXtoY(segments[segmentIndex], rate);

                if (n != 0) {
                    // a/b + c/d = (ad+bc)/bd
                    // totalBondPrice += (n / d);
                    // N = D*n + N*d, D = D*d
                    totalBondPriceN = totalBondPriceD.mul(n).add(
                        totalBondPriceN.mul(d)
                    );
                    totalBondPriceD = totalBondPriceD.mul(d);
                }
            }
            /**
             * @dev Ensure that totalBondPrice (= totalBondPriceN / totalBondPriceD) is the same
             * with rate. Because we need 1 Ether to mint a unit of each bond token respectively,
             * the sum of cashflow (USD) per a unit of bond token is the same as USD/ETH
             * rate at maturity.
             */
            require(
                totalBondPriceN == totalBondPriceD.mul(rate),
                "the total price at any rateBreakPoints should be the same value as the rate"
            );
        }
    }

    /**
     * @notice Collect bondIDs that regenerate the collateral, and group them as a bond group.
     * Any bond is described as a set of linear functions(i.e. polyline),
     * so we can easily check if the set of bondIDs are well-formed by looking at all the end
     * points of the lines.
     */
    function registerNewBondGroup(bytes32[] calldata bondIDs, uint256 maturity)
        external
        virtual
        override
        returns (uint256 bondGroupID)
    {
        _assertBondGroup(bondIDs, maturity);

        (, , uint64 sbtStrikePrice, ) = getBond(bondIDs[0]);
        for (uint256 i = 1; i < bondIDs.length; i++) {
            (, , uint64 strikePrice, ) = getBond(bondIDs[i]);
            require(
                strikePrice == 0,
                "except the first bond must not be pure SBT"
            );
        }

        // Get and increment next bond group ID
        bondGroupID = _nextBondGroupID;
        _nextBondGroupID = _nextBondGroupID.add(1);

        _bondGroupList[bondGroupID] = BondGroup(bondIDs, maturity);

        emit LogNewBondGroup(bondGroupID, maturity, sbtStrikePrice, bondIDs);

        return bondGroupID;
    }

    /**
     * @dev A user needs to issue a bond via BondGroup in order to guarantee that the total value
     * of bonds in the bond group equals to the token allowance except for about 0.2% fee (accurately 2/1002).
     * The fee send to Lien token contract when liquidateBond() or reverseBondGroupToCollateral().
     */
    function _issueNewBonds(
        uint256 bondGroupID,
        uint256 collateralAmountWithFee
    ) internal returns (uint256 bondAmount) {
        (bytes32[] memory bondIDs, uint256 maturity) =
            getBondGroup(bondGroupID);
        _assertNonEmptyBondGroup(bondIDs);
        _assertBeforeMaturity(maturity);

        uint256 fee = collateralAmountWithFee.mul(2).divRoundUp(1002);

        uint8 decimalsOfCollateral = _getCollateralDecimals();
        bondAmount = _applyDecimalGap(
            collateralAmountWithFee.sub(fee),
            decimalsOfCollateral,
            DECIMALS_OF_BOND
        );
        require(bondAmount != 0, "the minting amount must be non-zero");

        for (uint256 i = 0; i < bondIDs.length; i++) {
            _mintBond(bondIDs[i], msg.sender, bondAmount);
        }

        emit LogIssueNewBonds(bondGroupID, msg.sender, bondAmount);
    }

    /**
     * @notice redeems collateral from the total set of bonds in the bondGroupID before maturity date.
     * @param bondGroupID is the bond group ID.
     * @param bondAmount is the redeemed bond amount (decimal: 8).
     */
    function reverseBondGroupToCollateral(
        uint256 bondGroupID,
        uint256 bondAmount
    ) external virtual override returns (bool) {
        require(bondAmount != 0, "the bond amount must be non-zero");

        (bytes32[] memory bondIDs, uint256 maturity) =
            getBondGroup(bondGroupID);
        _assertNonEmptyBondGroup(bondIDs);
        _assertBeforeMaturity(maturity);
        for (uint256 i = 0; i < bondIDs.length; i++) {
            _burnBond(bondIDs[i], msg.sender, bondAmount);
        }

        uint8 decimalsOfCollateral = _getCollateralDecimals();
        uint256 collateralAmount =
            _applyDecimalGap(
                bondAmount,
                DECIMALS_OF_BOND,
                decimalsOfCollateral
            );

        uint256 fee = collateralAmount.mul(2).div(1000); // collateral:fee = 1000:2
        _sendCollateralTo(payable(FEE_TAKER), fee);
        _sendCollateralTo(msg.sender, collateralAmount);

        emit LogReverseBondGroupToCollateral(
            bondGroupID,
            msg.sender,
            collateralAmount
        );

        return true;
    }

    /**
     * @notice Burns set of LBTs and mints equivalent set of LBTs that are not in the exception list.
     * @param inputBondGroupID is the BondGroupID of bonds which you want to burn.
     * @param outputBondGroupID is the BondGroupID of bonds which you want to mint.
     * @param exceptionBonds is the list of bondIDs that should be excluded in burn/mint process.
     */
    function exchangeEquivalentBonds(
        uint256 inputBondGroupID,
        uint256 outputBondGroupID,
        uint256 amount,
        bytes32[] calldata exceptionBonds
    ) external virtual override returns (bool) {
        (bytes32[] memory inputIDs, uint256 inputMaturity) =
            getBondGroup(inputBondGroupID);
        _assertNonEmptyBondGroup(inputIDs);
        (bytes32[] memory outputIDs, uint256 outputMaturity) =
            getBondGroup(outputBondGroupID);
        _assertNonEmptyBondGroup(outputIDs);
        require(
            inputMaturity == outputMaturity,
            "cannot exchange bonds with different maturities"
        );
        _assertBeforeMaturity(inputMaturity);

        bool flag;
        uint256 exceptionCount;
        for (uint256 i = 0; i < inputIDs.length; i++) {
            // this flag control checks whether the bond is in the scope of burn/mint
            flag = true;
            for (uint256 j = 0; j < exceptionBonds.length; j++) {
                if (exceptionBonds[j] == inputIDs[i]) {
                    flag = false;
                    // this count checks if all the bondIDs in exceptionBonds are included both in inputBondGroupID and outputBondGroupID
                    exceptionCount = exceptionCount.add(1);
                }
            }
            if (flag) {
                _burnBond(inputIDs[i], msg.sender, amount);
            }
        }

        require(
            exceptionBonds.length == exceptionCount,
            "All the exceptionBonds need to be included in input"
        );

        for (uint256 i = 0; i < outputIDs.length; i++) {
            flag = true;
            for (uint256 j = 0; j < exceptionBonds.length; j++) {
                if (exceptionBonds[j] == outputIDs[i]) {
                    flag = false;
                    exceptionCount = exceptionCount.sub(1);
                }
            }
            if (flag) {
                _mintBond(outputIDs[i], msg.sender, amount);
            }
        }

        require(
            exceptionCount == 0,
            "All the exceptionBonds need to be included both in input and output"
        );

        emit LogExchangeEquivalentBonds(
            msg.sender,
            inputBondGroupID,
            outputBondGroupID,
            amount
        );

        return true;
    }

    /**
     * @notice This function distributes the collateral to the bond token holders
     * after maturity date based on the oracle price.
     * @param bondGroupID is the target bond group ID.
     * @param oracleHintID is manually set to be smaller number than the oracle latestId
     * when the caller wants to save gas.
     */
    function liquidateBond(uint256 bondGroupID, uint256 oracleHintID)
        external
        virtual
        override
        returns (uint256 totalPayment)
    {
        (bytes32[] memory bondIDs, uint256 maturity) =
            getBondGroup(bondGroupID);
        _assertNonEmptyBondGroup(bondIDs);
        require(
            _getBlockTimestampSec() >= maturity,
            "the bond has not expired yet"
        );

        uint256 latestID = _oracleContract.latestId();
        require(
            latestID != 0,
            "system error: the ID of oracle data should not be zero"
        );

        uint256 price =
            _getPriceOn(
                maturity,
                (oracleHintID != 0 && oracleHintID <= latestID)
                    ? oracleHintID
                    : latestID
            );
        require(price != 0, "price should be non-zero value");
        require(price < 2**64, "price should be less than 2^64");

        for (uint256 i = 0; i < bondIDs.length; i++) {
            bytes32 bondID = bondIDs[i];
            uint256 payment =
                _sendCollateralToBondTokenContract(bondID, uint64(price));
            totalPayment = totalPayment.add(payment);
        }

        if (totalPayment != 0) {
            uint256 fee = totalPayment.mul(2).div(1000); // collateral:fee = 1000:2
            _sendCollateralTo(payable(FEE_TAKER), fee);
        }
    }

    function collateralAddress() external view override returns (address) {
        return _collateralAddress();
    }

    function oracleAddress()
        external
        view
        override
        returns (PriceOracleInterface)
    {
        return _oracleContract;
    }

    function feeTaker() external view override returns (address) {
        return FEE_TAKER;
    }

    function decimalsOfBond() external view override returns (uint8) {
        return DECIMALS_OF_BOND;
    }

    function decimalsOfOraclePrice() external view override returns (uint8) {
        return DECIMALS_OF_ORACLE_PRICE;
    }

    function maturityScale() external view override returns (uint256) {
        return MATURITY_SCALE;
    }

    function nextBondGroupID() external view override returns (uint256) {
        return _nextBondGroupID;
    }

    /**
     * @notice Returns multiple information for the bondID.
     * @dev The decimals of strike price is the same as that of oracle price.
     */
    function getBond(bytes32 bondID)
        public
        view
        override
        returns (
            address bondTokenAddress,
            uint256 maturity,
            uint64 solidStrikePrice,
            bytes32 fnMapID
        )
    {
        BondInfo memory bondInfo = _bonds[bondID];
        bondTokenAddress = address(bondInfo.contractInstance);
        maturity = bondInfo.maturity;
        solidStrikePrice = bondInfo.strikePrice;
        fnMapID = bondInfo.fnMapID;
    }

    /**
     * @dev Returns polyline for the fnMapID.
     */
    function getFnMap(bytes32 fnMapID)
        public
        view
        override
        returns (bytes memory fnMap)
    {
        LineSegment[] storage segments = _registeredFnMap[fnMapID];
        uint256[] memory polyline = new uint256[](segments.length);
        for (uint256 i = 0; i < segments.length; i++) {
            polyline[i] = zipLineSegment(segments[i]);
        }
        return abi.encode(polyline);
    }

    /**
     * @dev Returns all the bondIDs and their maturity for the bondGroupID.
     */
    function getBondGroup(uint256 bondGroupID)
        public
        view
        override
        returns (bytes32[] memory bondIDs, uint256 maturity)
    {
        require(
            bondGroupID < _nextBondGroupID,
            "the bond group does not exist"
        );
        BondGroup memory bondGroup = _bondGroupList[bondGroupID];
        bondIDs = bondGroup.bondIDs;
        maturity = bondGroup.maturity;
    }

    /**
     * @dev Returns keccak256 for the fnMap.
     */
    function generateFnMapID(bytes memory fnMap)
        public
        pure
        override
        returns (bytes32 fnMapID)
    {
        return keccak256(fnMap);
    }

    /**
     * @dev Returns a bond ID determined by this contract address, maturity and fnMap.
     */
    function generateBondID(uint256 maturity, bytes memory fnMap)
        public
        view
        override
        returns (bytes32 bondID)
    {
        return keccak256(abi.encodePacked(address(this), maturity, fnMap));
    }

    function _mintBond(
        bytes32 bondID,
        address account,
        uint256 amount
    ) internal {
        BondTokenInterface bondTokenContract = _bonds[bondID].contractInstance;
        _assertRegisteredBond(bondTokenContract);
        require(
            bondTokenContract.mint(account, amount),
            "failed to mint bond token"
        );
    }

    function _burnBond(
        bytes32 bondID,
        address account,
        uint256 amount
    ) internal {
        BondTokenInterface bondTokenContract = _bonds[bondID].contractInstance;
        _assertRegisteredBond(bondTokenContract);
        require(
            bondTokenContract.simpleBurn(account, amount),
            "failed to burn bond token"
        );
    }

    function _sendCollateralToBondTokenContract(bytes32 bondID, uint64 price)
        internal
        returns (uint256 collateralAmount)
    {
        BondTokenInterface bondTokenContract = _bonds[bondID].contractInstance;
        _assertRegisteredBond(bondTokenContract);

        LineSegment[] storage segments =
            _registeredFnMap[_bonds[bondID].fnMapID];

        (uint256 segmentIndex, bool ok) = _correspondSegment(segments, price);
        assert(ok); // not found a segment whose price range include current price

        (uint128 n, uint64 _d) = _mapXtoY(segments[segmentIndex], price); // x = price, y = n / _d

        // uint64(-1) *  uint64(-1) < uint128(-1)
        uint128 d = uint128(_d) * uint128(price);

        uint256 totalSupply = bondTokenContract.totalSupply();
        bool expiredFlag = bondTokenContract.expire(n, d); // rateE0 = n / d = f(price) / price

        if (expiredFlag) {
            uint8 decimalsOfCollateral = _getCollateralDecimals();
            collateralAmount = _applyDecimalGap(
                totalSupply,
                DECIMALS_OF_BOND,
                decimalsOfCollateral
            )
                .mul(n)
                .div(d);
            _sendCollateralTo(address(bondTokenContract), collateralAmount);

            emit LogLiquidateBond(bondID, n, d);
        }
    }

    /**
     * @dev Get the price of the oracle data with a minimum timestamp that does more than input value
     * when you know the ID you are looking for.
     * @param timestamp is the timestamp that you want to get price.
     * @param hintID is the ID of the oracle data you are looking for.
     * @return priceE8 (10^-8 USD)
     */
    function _getPriceOn(uint256 timestamp, uint256 hintID)
        internal
        returns (uint256 priceE8)
    {
        require(
            _oracleContract.getTimestamp(hintID) > timestamp,
            "there is no price data after maturity"
        );

        uint256 id = hintID - 1;
        while (id != 0) {
            if (_oracleContract.getTimestamp(id) <= timestamp) {
                break;
            }
            id--;
        }

        return _oracleContract.getPrice(id + 1);
    }

    /**
     * @dev removes a decimal gap from rate.
     */
    function _applyDecimalGap(
        uint256 baseAmount,
        uint8 decimalsOfBase,
        uint8 decimalsOfQuote
    ) internal pure returns (uint256 quoteAmount) {
        uint256 n;
        uint256 d;

        if (decimalsOfBase > decimalsOfQuote) {
            d = decimalsOfBase - decimalsOfQuote;
        } else if (decimalsOfBase < decimalsOfQuote) {
            n = decimalsOfQuote - decimalsOfBase;
        }

        // The consequent multiplication would overflow under extreme and non-blocking circumstances.
        require(n < 19 && d < 19, "decimal gap needs to be lower than 19");
        quoteAmount = baseAmount.mul(10**n).div(10**d);
    }

    function _assertRegisteredBond(BondTokenInterface bondTokenContract)
        internal
        pure
    {
        require(
            address(bondTokenContract) != address(0),
            "the bond is not registered"
        );
    }

    function _assertNonEmptyBondGroup(bytes32[] memory bondIDs) internal pure {
        require(bondIDs.length != 0, "the list of bond ID must be non-empty");
    }

    function _assertBeforeMaturity(uint256 maturity) internal view {
        require(
            _getBlockTimestampSec() < maturity,
            "the maturity has already expired"
        );
    }

    function _isBondWorthless(LineSegment[] memory polyline)
        internal
        pure
        returns (bool)
    {
        for (uint256 i = 0; i < polyline.length; i++) {
            LineSegment memory segment = polyline[i];
            if (segment.right.y != 0) {
                return false;
            }
        }

        return true;
    }

    /**
     * @dev Return the strike price only when the form of polyline matches to the definition of SBT.
     * Check if the form is SBT even when the polyline is in a verbose style.
     */
    function _getSbtStrikePrice(LineSegment[] memory polyline)
        internal
        pure
        returns (uint64)
    {
        if (polyline.length != 2) {
            return 0;
        }

        uint64 strikePrice = polyline[0].right.x;

        if (strikePrice == 0) {
            return 0;
        }

        for (uint256 i = 0; i < polyline.length; i++) {
            LineSegment memory segment = polyline[i];
            if (segment.right.y != strikePrice) {
                return 0;
            }
        }

        return uint64(strikePrice);
    }

    /**
     * @dev Only when the form of polyline matches to the definition of LBT, this function returns
     * the minimum collateral price (USD) that LBT is not worthless.
     * Check if the form is LBT even when the polyline is in a verbose style.
     */
    function _getLbtStrikePrice(LineSegment[] memory polyline)
        internal
        pure
        returns (uint64)
    {
        if (polyline.length != 2) {
            return 0;
        }

        uint64 strikePrice = polyline[0].right.x;

        if (strikePrice == 0) {
            return 0;
        }

        for (uint256 i = 0; i < polyline.length; i++) {
            LineSegment memory segment = polyline[i];
            if (segment.right.y.add(strikePrice) != segment.right.x) {
                return 0;
            }
        }

        return uint64(strikePrice);
    }

    /**
     * @dev In order to calculate y axis value for the corresponding x axis value, we need to find
     * the place of domain of x value on the polyline.
     * As the polyline is already checked to be correctly formed, we can simply look from the right
     * hand side of the polyline.
     */
    function _correspondSegment(LineSegment[] memory segments, uint64 x)
        internal
        pure
        returns (uint256 i, bool ok)
    {
        i = segments.length;
        while (i > 0) {
            i--;
            if (segments[i].left.x <= x) {
                ok = true;
                break;
            }
        }
    }

    // function issueNewBonds(uint256 bondGroupID, uint256 amount) external returns (uint256 bondAmount);

    function _createNewBondToken(uint256 maturity, bytes memory fnMap)
        internal
        virtual
        returns (BondTokenInterface);

    function _collateralAddress() internal view virtual returns (address);

    function _getCollateralDecimals() internal view virtual returns (uint8);

    function _sendCollateralTo(address receiver, uint256 amount)
        internal
        virtual;
}
