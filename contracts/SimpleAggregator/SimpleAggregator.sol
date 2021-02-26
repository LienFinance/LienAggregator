// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;
import "../Interfaces/StrategyInterface.sol";
import "../Interfaces/SimpleAggragatorInterface.sol";
import "../Interfaces/ExchangeInterface.sol";
import "../BondToken_and_GDOTC/bondToken/BondTokenInterface.sol";
import "./BondPricerWithAcceptableMaturity.sol";
import "../Interfaces/BondRegistratorInterface.sol";
import "../Interfaces/UseVolatilityOracle.sol";
import "../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";
import "../../node_modules/@openzeppelin/contracts/utils/SafeCast.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

abstract contract SimpleAggregator is SimpleAggregatorInterface, UseVolatilityOracle {
    using SafeMath for uint256;
    using SafeCast for uint256;
    using SafeERC20 for ERC20;
    struct ReceivedCollateral {
        uint128 term;
        uint128 value;
    }
    struct UnRemovedToken {
        uint128 term;
        uint128 value;
    }
    struct LiquidationData {
        uint32 endBondGroupId;
        uint32 liquidatedBondGroupID;
        bool isLiquidated;
    }
    struct TermInfo {
        uint64 maturity;
        uint64 strikePrice;
        bytes32 SBTId;
    }
    struct ShareData {
        uint128 totalShare;
        uint128 totalCollateralPerToken;
    }
    struct BalanceData {
        uint128 balance;
        uint64 rewardAmount;
        uint64 term;
    }

    uint256 constant INFINITY = uint256(-1);
    uint256 constant COOLTIME = 3600 * 24 * 3;
    SimpleStrategyInterface internal immutable STRATEGY;
    ExchangeInterface internal immutable DOTC;
    ERC20 internal immutable REWARD_TOKEN;
    BondPricerWithAcceptableMaturity internal immutable BOND_PRICER;
    LatestPriceOracleInterface internal immutable ORACLE;
    BondMakerInterface internal immutable BONDMAKER;
    BondRegistratorInterface internal immutable BOND_REGISTRATOR;
    address internal immutable OWNER;
    bool internal immutable REVERSE_ORACLE;
    int16 internal constant MAX_SUPPLY_DENUMERATOR = 8;
    uint64 internal immutable BASE_PRICE_UNIT;
    mapping(uint256 => TermInfo) internal termInfo;

    mapping(uint256 => uint256[]) internal issuableBondGroupIds;
    mapping(uint256 => mapping(uint256 => uint256)) internal strikePriceToBondGroup;

    TotalReward[] internal totalRewards;
    // Aggregator Status
    mapping(uint256 => LiquidationData) internal liquidationData;
    mapping(uint256 => ShareData) internal shareData;
    uint256 internal currentTerm;
    uint64 internal priceUnit;
    uint64 internal lastTrancheTime;
    uint32 internal startBondGroupId = 1;
    int16 internal currentFeeBase;
    bool internal isTotalSupplyDanger;

    mapping(address => ReceivedCollateral) internal receivedCollaterals;
    mapping(address => UnRemovedToken) internal unremovedTokens;
    mapping(address => BalanceData) internal balance;
    mapping(address => mapping(address => uint128)) internal allowances;

    uint8 public constant override decimals = 8;
    string public constant override symbol = "LASH";
    string public constant override name = "LIEN_AGGREGATOR_SHARE";

    mapping(uint256 => uint128) internal totalReceivedCollateral;
    mapping(uint256 => uint128) internal totalUnremovedTokens;

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    event SetAddLiquidity(address indexed user, uint256 indexed term, uint256 collateralAmount);

    event SetRemoveLiquidity(address indexed user, uint256 indexed term, uint256 tokenAmount);

    event SettleLiquidity(
        address indexed user,
        uint256 indexed term,
        uint256 collateralAmount,
        uint256 tokenAmount
    );

    event TrancheBond(
        uint64 indexed issueBondGroupId,
        uint64 issueAmount,
        uint64 indexed burnBondGroupId,
        uint64 burnAmount
    );

    event UpdateMaturity(uint64 indexed term, int16 newFeeBase, uint64 maturity);

    event AddLiquidity(address indexed user, uint256 tokenAmount);

    modifier isActive() {
        require(block.timestamp <= termInfo[currentTerm].maturity, "Aggregator is not active");
        _;
    }

    modifier endCoolTime() {
        require(block.timestamp > lastTrancheTime + COOLTIME, "In the Cool Time");
        _;
    }

    modifier afterMaturity() {
        require(block.timestamp > termInfo[currentTerm].maturity, "Not Matured");
        _;
    }

    modifier isRunning() {
        require(currentTerm != 0, "Not running");
        _;
    }

    // When collateralPerToken becomes very small value, total supply of share token can overflow
    modifier isSafeSupply() {
        require(!isTotalSupplyDanger, "TotalSupply is unsafe");
        _;
    }

    modifier onlyBonusProvider() {
        require(msg.sender == OWNER, "Restricted to the reward provider");
        _;
    }

    constructor(
        LatestPriceOracleInterface _oracle,
        BondPricerWithAcceptableMaturity _pricer,
        SimpleStrategyInterface _strategy,
        ERC20 _rewardToken,
        BondRegistratorInterface _registrator,
        ExchangeInterface _exchangeAddress,
        uint64 _priceUnit,
        uint64 _firstRewardRate,
        bool _reverseOracle,
        VolatilityOracleInterface _volOracle
    ) UseVolatilityOracle(_volOracle) {
        BONDMAKER = _exchangeAddress.bondMakerAddress();
        BOND_PRICER = _pricer;
        ORACLE = _oracle;
        BASE_PRICE_UNIT = _priceUnit;
        REVERSE_ORACLE = _reverseOracle;
        REWARD_TOKEN = _rewardToken;
        BOND_REGISTRATOR = _registrator;
        DOTC = _exchangeAddress;

        STRATEGY = _strategy;

        totalRewards.push(TotalReward(1, _firstRewardRate));
        priceUnit = _priceUnit;
        OWNER = msg.sender;
        require(
            _firstRewardRate >= 10**decimals && _firstRewardRate <= 1000000 * 10**decimals,
            "Out of valid range"
        );
    }

    /**
     * @notice Update maturity and strike price of SBT
     * Then, determine total amount of collateral asset and totalSupply of share token
     * Collateral asset to be withdrawn in `settleTokens()` is sent for reserve contract
     */
    function renewMaturity() public override {
        uint256 totalUnsentTokens;
        uint256 collateralPerTokenE8;
        uint256 _currentTerm = currentTerm;
        uint256 currentUnremoved = totalUnremovedTokens[_currentTerm];
        require(liquidationData[_currentTerm].isLiquidated || _currentTerm == 0, "Not expired yet");
        uint256 totalShare = shareData[_currentTerm].totalShare;
        if (totalShare > 0) {
            uint256 collateralAmount = getCollateralAmount();
            collateralPerTokenE8 = _applyDecimalGap(
                collateralAmount.mul(10**decimals).div(totalShare),
                true
            );
            totalUnsentTokens = _applyDecimalGap(
                uint256(totalReceivedCollateral[_currentTerm]).mul(10**decimals) /
                    collateralPerTokenE8,
                true
            );
        } else if (totalReceivedCollateral[_currentTerm] > 0) {
            totalUnsentTokens = _applyDecimalGap(totalReceivedCollateral[_currentTerm], true);
            collateralPerTokenE8 = 10**decimals;
        }

        uint256 _totalSupply = totalShare + totalUnsentTokens;
        shareData[_currentTerm + 1].totalCollateralPerToken = collateralPerTokenE8.toUint128();
        shareData[_currentTerm + 1].totalShare = uint256(totalShare)
            .add(totalUnsentTokens)
            .sub(currentUnremoved)
            .toUint128();

        if (
            shareData[_currentTerm + 1].totalShare >
            uint128(-1) / 10**uint128(MAX_SUPPLY_DENUMERATOR)
        ) {
            isTotalSupplyDanger = true;
        }

        if (_currentTerm != 0) {
            _updateFeeBase();
        }

        if (_totalSupply > 0 && currentUnremoved > 0) {
            _reserveAsset(collateralPerTokenE8);
        }
        _updateBondGroupData();

        emit UpdateMaturity(currentTerm.toUint64(), currentFeeBase, termInfo[currentTerm].maturity);
    }

    /**
     * @notice Update total reward token amount for one term
     * Only owner can call this function
     * @param rewardRate is restricted from 10**8 (1 LIEN) to 10**14 (total supply of Lien token)
     */
    function updateTotalReward(uint64 rewardRate) public onlyBonusProvider isRunning {
        require(
            rewardRate >= 10**decimals && rewardRate <= 1000000 * 10**decimals,
            "Out of valid range"
        );
        totalRewards.push(TotalReward(currentTerm.toUint64() + 1, rewardRate));
    }

    function _updateBondGroupData() internal {
        uint256 nextTimeStamp = STRATEGY.calcNextMaturity();
        uint256 currentPriceE8 = ORACLE.latestPrice();
        uint256 currentStrikePrice = STRATEGY.getCurrentStrikePrice(
            currentPriceE8,
            priceUnit,
            REVERSE_ORACLE
        );

        _updatePriceUnit(currentPriceE8);

        // Register SBT for next term
        bytes32 SBTId = BOND_REGISTRATOR.registerSBT(
            BONDMAKER,
            currentStrikePrice.toUint64(),
            nextTimeStamp.toUint64()
        );

        currentTerm += 1;
        TermInfo memory newTermInfo = TermInfo(
            nextTimeStamp.toUint64(),
            currentStrikePrice.toUint64(),
            SBTId
        );
        termInfo[currentTerm] = newTermInfo;
        BOND_PRICER.updateAcceptableMaturity(nextTimeStamp);
    }

    function _addLiquidity(uint256 amount) internal returns (bool success) {
        (, uint256 unsentToken, uint256 addLiquidityTerm) = _settleTokens();
        _updateBalanceDataForLiquidityMove(msg.sender, unsentToken, 0, addLiquidityTerm);
        uint256 _currentTerm = currentTerm;
        if (receivedCollaterals[msg.sender].value == 0) {
            receivedCollaterals[msg.sender].term = uint128(_currentTerm);
        }
        receivedCollaterals[msg.sender].value += amount.toUint128();
        totalReceivedCollateral[_currentTerm] += amount.toUint128();
        emit SetAddLiquidity(msg.sender, _currentTerm, amount);
        return true;
    }

    /**
     * @notice Make a reservation for removing liquidity
     * Collateral asset can be withdrawn from next term
     * Share token to be removed is burned at this point
     * Before remove liquidity, run _settleTokens()
     */

    function removeLiquidity(uint128 amount) external override returns (bool success) {
        (, uint256 unsentToken, uint256 addLiquidityTerm) = _settleTokens();
        uint256 _currentTerm = currentTerm;
        if (unremovedTokens[msg.sender].value == 0) {
            unremovedTokens[msg.sender].term = uint128(_currentTerm);
        }
        unremovedTokens[msg.sender].value += amount;
        totalUnremovedTokens[_currentTerm] += amount;
        _updateBalanceDataForLiquidityMove(msg.sender, unsentToken, amount, addLiquidityTerm);
        emit SetRemoveLiquidity(msg.sender, _currentTerm, amount);
        return true;
    }

    function _settleTokens()
        internal
        returns (
            uint256 unsentETH,
            uint256 unsentToken,
            uint256 addLiquidityTerm
        )
    {
        uint256 _currentTerm = currentTerm;
        uint128 lastRemoveLiquidityTerm = unremovedTokens[msg.sender].term;
        uint128 lastRemoveLiquidityValue = unremovedTokens[msg.sender].value;
        uint128 lastAddLiquidityTerm = receivedCollaterals[msg.sender].term;
        uint128 lastAddLiquidityValue = receivedCollaterals[msg.sender].value;
        if (_currentTerm == 0) {
            return (0, 0, 0);
        }

        if (lastRemoveLiquidityValue != 0 && _currentTerm > lastRemoveLiquidityTerm) {
            unsentETH = _applyDecimalGap(
                uint256(lastRemoveLiquidityValue)
                    .mul(shareData[uint256(lastRemoveLiquidityTerm + 1)].totalCollateralPerToken)
                    .div(10**decimals),
                false
            );
            if (unsentETH > 0) {
                _sendTokens(msg.sender, unsentETH);
            }
            delete unremovedTokens[msg.sender];
        }

        if (lastAddLiquidityValue != 0 && _currentTerm > lastAddLiquidityTerm) {
            unsentToken = _applyDecimalGap(
                uint256(lastAddLiquidityValue).mul(10**decimals).div(
                    uint256(shareData[lastAddLiquidityTerm + 1].totalCollateralPerToken)
                ),
                true
            );
            addLiquidityTerm = lastAddLiquidityTerm;
            delete receivedCollaterals[msg.sender];
        }
        emit SettleLiquidity(msg.sender, _currentTerm, unsentETH, unsentToken);
    }

    /**
     * @notice Increment share token for addLiquidity data
     * Transfer collateral asset for remove liquidity data
     */
    function settleTokens() external override returns (uint256 unsentETH, uint256 unsentToken) {
        uint256 addLiquidityTerm;
        (unsentETH, unsentToken, addLiquidityTerm) = _settleTokens();
        _updateBalanceDataForLiquidityMove(msg.sender, unsentToken, 0, addLiquidityTerm);
    }

    /**
     * @notice Update `startBondGroupId` to run `liquidateBonds()` more efficiently
     * All bond groups before `startBondGroupId` has expired before maturity of previous term
     */
    function updateStartBondGroupId() external override isRunning {
        uint32 _startBondGroupId = startBondGroupId;
        uint64 previousMaturity = termInfo[currentTerm - 1].maturity;
        require(previousMaturity != 0, "Maturity shoudld exist");
        while (true) {
            (, uint256 maturity) = BONDMAKER.getBondGroup(_startBondGroupId);
            if (maturity >= previousMaturity) {
                startBondGroupId = _startBondGroupId;
                return;
            }
            _startBondGroupId += 1;
        }
    }

    /**
     * @notice Liquidate and burn all bonds in this aggregator
     * Aggregator can search for 50 bondGroup and burn 10 bonds one time
     */
    function liquidateBonds() public override afterMaturity {
        uint256 _currentTerm = currentTerm;
        require(!liquidationData[_currentTerm].isLiquidated, "All bonds expired");
        if (liquidationData[_currentTerm].endBondGroupId == 0) {
            liquidationData[_currentTerm].endBondGroupId = BONDMAKER.nextBondGroupID().toUint32();
        }
        // ToDo: Register least bond group ID
        uint32 endIndex;
        uint32 startIndex;
        uint32 liquidateBondNumber;
        uint64 maturity = termInfo[_currentTerm].maturity;
        uint64 previousMaturity = termInfo[_currentTerm - 1].maturity;
        {
            uint256 ethAllowance = DOTC.ethAllowance(address(this));
            if (ethAllowance > 0) {
                DOTC.withdrawEth();
            }
        }

        if (liquidationData[_currentTerm].liquidatedBondGroupID == 0) {
            startIndex = startBondGroupId;
        } else {
            startIndex = liquidationData[_currentTerm].liquidatedBondGroupID;
        }

        if (liquidationData[_currentTerm].endBondGroupId - startIndex > 50) {
            endIndex = startIndex + 50;
            liquidationData[_currentTerm].liquidatedBondGroupID = endIndex;
        } else {
            endIndex = liquidationData[_currentTerm].endBondGroupId;
        }

        for (uint256 i = startIndex; i < endIndex; i++) {
            liquidateBondNumber = _liquidateBondGroup(
                i,
                liquidateBondNumber,
                maturity,
                previousMaturity
            );

            if (liquidateBondNumber > 9) {
                if (i == endIndex - 1) {
                    liquidationData[_currentTerm].isLiquidated = true;
                } else {
                    liquidationData[_currentTerm].liquidatedBondGroupID = uint32(i + 1);
                }
                return;
            }
        }

        if (endIndex == liquidationData[_currentTerm].endBondGroupId) {
            liquidationData[_currentTerm].isLiquidated = true;
        } else {
            liquidationData[_currentTerm].liquidatedBondGroupID = endIndex;
        }
    }

    function addSuitableBondGroup() external override isActive returns (uint256 bondGroupID) {
        uint256 currentPriceE8 = ORACLE.latestPrice();
        return _addSuitableBondGroup(currentPriceE8);
    }

    /**
     * @notice Can not tranche bonds for 3 days from last execution of this function
     */
    function trancheBonds() external override isActive endCoolTime {
        uint256 currentPriceE8 = ORACLE.latestPrice();
        uint256 bondGroupId = _getSuitableBondGroup(currentPriceE8);
        if (bondGroupId == 0) {
            bondGroupId = _addSuitableBondGroup(currentPriceE8);
        }

        (uint256 amount, uint256 ethAmount, uint256[2] memory reverseBonds) = STRATEGY
            .getTrancheBonds(
            BONDMAKER,
            address(this),
            bondGroupId,
            currentPriceE8,
            issuableBondGroupIds[currentTerm],
            priceUnit,
            REVERSE_ORACLE
        );

        if (ethAmount > 0) {
            DOTC.depositEth{value: ethAmount}();
        }

        if (amount > 0) {
            _issueBonds(bondGroupId, amount);
        }

        if (reverseBonds[1] > 0) {
            // Burn bond and get collateral asset
            require(
                BONDMAKER.reverseBondGroupToCollateral(reverseBonds[0], reverseBonds[1]),
                "Could not reverse LBTs"
            );
        }
        lastTrancheTime = block.timestamp.toUint64();
        emit TrancheBond(
            uint64(bondGroupId),
            uint64(amount),
            uint64(reverseBonds[0]),
            uint64(reverseBonds[1])
        );
    }

    function _burnBond(
        uint256 bondGroupId,
        address bondAddress,
        uint32 liquidateBondNumber,
        bool isLiquidated
    ) internal returns (uint32, bool) {
        BondTokenInterface bond = BondTokenInterface(bondAddress);
        if (bond.balanceOf(address(this)) > 0) {
            if (!isLiquidated) {
                // If this bond group is not liquidated in _liquidateBondGroup, try liquidate
                // BondMaker contract does not revert even if someone else calls 'BONDMAKER.liquidateBond()'
                BONDMAKER.liquidateBond(bondGroupId, 0);
                isLiquidated = true;
            }
            bond.burnAll();
            liquidateBondNumber += 1;
        }
        return (liquidateBondNumber, isLiquidated);
    }

    function _liquidateBondGroup(
        uint256 bondGroupId,
        uint32 liquidateBondNumber,
        uint64 maturity,
        uint64 previousMaturity
    ) internal returns (uint32) {
        (bytes32[] memory bondIds, uint256 _maturity) = BONDMAKER.getBondGroup(bondGroupId);
        if (_maturity > maturity || (_maturity < previousMaturity && previousMaturity != 0)) {
            return liquidateBondNumber;
        }
        bool isLiquidated;
        for (uint256 i = 0; i < bondIds.length; i++) {
            (address bondAddress, , , ) = BONDMAKER.getBond(bondIds[i]);
            (liquidateBondNumber, isLiquidated) = _burnBond(
                bondGroupId,
                bondAddress,
                liquidateBondNumber,
                isLiquidated
            );
        }
        return liquidateBondNumber;
    }

    function _getSuitableBondGroup(uint256 currentPriceE8) internal view returns (uint256) {
        uint256 roundedPrice = STRATEGY.calcRoundPrice(currentPriceE8, priceUnit, 1);


            mapping(uint256 => uint256) storage priceToGroupBondId
         = strikePriceToBondGroup[currentTerm];
        if (priceToGroupBondId[roundedPrice] != 0) {
            return priceToGroupBondId[roundedPrice];
        }
        // Suitable bond range is in between current price +- 2 * priceUnit
        for (uint256 i = 1; i <= 2; i++) {
            if (priceToGroupBondId[roundedPrice - priceUnit * i] != 0) {
                return priceToGroupBondId[roundedPrice - priceUnit * i];
            }

            if (priceToGroupBondId[roundedPrice + priceUnit * i] != 0) {
                return priceToGroupBondId[roundedPrice + priceUnit * i];
            }
        }
    }

    function _addSuitableBondGroup(uint256 currentPriceE8) internal returns (uint256 bondGroupID) {
        uint256 callStrikePrice = STRATEGY.calcCallStrikePrice(
            currentPriceE8,
            priceUnit,
            REVERSE_ORACLE
        );
        uint256 _currentTerm = currentTerm;
        TermInfo memory info = termInfo[_currentTerm];
        callStrikePrice = _adjustPrice(info.strikePrice, callStrikePrice);
        bondGroupID = BOND_REGISTRATOR.registerBondGroup(
            BONDMAKER,
            callStrikePrice,
            info.strikePrice,
            info.maturity,
            info.SBTId
        );
        // If reverse oracle is set to aggregator, make Collateral/USD price
        if (REVERSE_ORACLE) {
            _addBondGroup(
                bondGroupID,
                STRATEGY.calcCallStrikePrice(currentPriceE8, priceUnit, false)
            );
        } else {
            _addBondGroup(bondGroupID, callStrikePrice);
        }
    }

    function _addBondGroup(uint256 bondGroupId, uint256 callStrikePriceInEthUSD) internal {
        // Register bond group info
        issuableBondGroupIds[currentTerm].push(bondGroupId);
        strikePriceToBondGroup[currentTerm][callStrikePriceInEthUSD] = bondGroupId;

        (bytes32[] memory bondIDs, ) = BONDMAKER.getBondGroup(bondGroupId);
        (address bondType1Address, , , ) = BONDMAKER.getBond(bondIDs[1]);

        // Infinite approve if no approval
        if (IERC20(bondType1Address).allowance(address(this), address(DOTC)) == 0) {
            IERC20(bondType1Address).approve(address(DOTC), INFINITY);
        }

        (address bondType2Address, , , ) = BONDMAKER.getBond(bondIDs[2]);

        if (IERC20(bondType2Address).allowance(address(this), address(DOTC)) == 0) {
            IERC20(bondType2Address).approve(address(DOTC), INFINITY);
        }
        (address bondType3Address, , , ) = BONDMAKER.getBond(bondIDs[3]);
        if (IERC20(bondType3Address).allowance(address(this), address(DOTC)) == 0) {
            IERC20(bondType3Address).approve(address(DOTC), INFINITY);
        }
    }

    function _updatePriceUnit(uint256 currentPriceE8) internal {
        uint256 multiplyer = currentPriceE8.div(50 * BASE_PRICE_UNIT);
        if (multiplyer == 0) {
            priceUnit = BASE_PRICE_UNIT;
        } else {
            priceUnit = ((25 * multiplyer * BASE_PRICE_UNIT) / 10).toUint64();
        }
    }

    function _updateFeeBase() internal {
        STRATEGY.registerCurrentFeeBase(
            currentFeeBase,
            shareData[currentTerm].totalCollateralPerToken,
            shareData[currentTerm + 1].totalCollateralPerToken,
            OWNER,
            address(ORACLE),
            REVERSE_ORACLE
        );
        changeSpread();
    }

    /**
     * @dev When sbtStrikePrice and callStrikePrice have different remainder of 2,
     * decrease callStrikePrice by 1 to avoid invalid line segment for register new bond
     */
    function _adjustPrice(uint64 sbtStrikePrice, uint256 callStrikePrice)
        internal
        pure
        returns (uint256)
    {
        return callStrikePrice.sub(callStrikePrice.sub(sbtStrikePrice) % 2);
    }

    function changeSpread() public virtual override {}

    function _sendTokens(address user, uint256 amount) internal virtual {}

    function _reserveAsset(uint256 reserveAmountRatioE8) internal virtual {}

    function _issueBonds(uint256 bondgroupID, uint256 amount) internal virtual {}

    function getCollateralAddress() external view virtual override returns (address) {}

    function _applyDecimalGap(uint256 amount, bool isDiv) internal view virtual returns (uint256) {}

    function getCollateralDecimal() external view virtual override returns (int16) {}

    function getReserveAddress() external view virtual returns (address) {}

    function getCollateralAmount() public view virtual override returns (uint256) {}

    // Reward functions
    /**
     * @dev Update reward amount, then update balance
     */
    function _updateBalanceData(address owner, int256 amount) internal {
        BalanceData memory balanceData = balance[owner];
        balanceData.rewardAmount = _calcNextReward(balanceData, currentTerm);
        balanceData.term = uint64(currentTerm);
        if (amount < 0) {
            balanceData.balance = uint256(balanceData.balance)
                .sub(uint256(amount * -1))
                .toUint128();
        } else {
            balanceData.balance = uint256(balanceData.balance).add(uint256(amount)).toUint128();
        }
        balance[owner] = balanceData;
    }

    function _updateBalanceDataForLiquidityMove(
        address owner,
        uint256 addAmount,
        uint256 removeAmount,
        uint256 term
    ) internal {
        BalanceData memory balanceData = balance[owner];
        // Update reward amount before addliquidity
        if (addAmount != 0) {
            balanceData.rewardAmount = _calcNextReward(balanceData, term);
            balanceData.term = uint64(term);
            balanceData.balance = balanceData.balance = uint256(balanceData.balance)
                .add(uint256(addAmount))
                .toUint128();
        }
        // Update reward amount after addliquidity
        balanceData.rewardAmount = _calcNextReward(balanceData, currentTerm);
        balanceData.term = uint64(currentTerm);
        // Update balance if remove liquidity
        if (removeAmount != 0) {
            balanceData.balance = uint256(balanceData.balance).sub(removeAmount).toUint128();
        }
        balance[owner] = balanceData;
    }

    /**
     * @dev This function is called before change balance of share token
     * @param term Reward amount is calculated from next term after this function is called to  term `term`
     */
    function _calcNextReward(BalanceData memory balanceData, uint256 term)
        internal
        view
        returns (uint64 rewardAmount)
    {
        rewardAmount = balanceData.rewardAmount;
        if (balanceData.balance > 0 && balanceData.term < term) {
            uint64 index = uint64(totalRewards.length - 1);
            uint64 referenceTerm = totalRewards[index].term;
            uint64 rewardTotal = totalRewards[index].value;

            for (uint256 i = term; i > balanceData.term; i--) {
                if (i < referenceTerm) {
                    // If i is smaller than the term in which total reward amount is changed, update total reward amount
                    index -= 1;
                    rewardTotal = totalRewards[index].value;
                    referenceTerm = totalRewards[index].term;
                }
                // Reward amount is calculated by `total reward amount * user balance / total share`
                rewardAmount = uint256(rewardAmount)
                    .add(
                    (uint256(rewardTotal).mul(balanceData.balance)).div(shareData[i].totalShare)
                )
                    .toUint64();
            }
        }
    }

    /**
     * @notice update reward amount and transfer reward token, then change reward amount to 0
     */
    function claimReward() public override {
        BalanceData memory userData = balance[msg.sender];
        userData.rewardAmount = _calcNextReward(userData, currentTerm);
        userData.term = uint64(currentTerm);
        require(userData.rewardAmount > 0, "User should have reward");
        uint256 rewardAmount = userData.rewardAmount;
        userData.rewardAmount = 0;
        balance[msg.sender] = userData;
        REWARD_TOKEN.safeTransfer(msg.sender, rewardAmount);
    }

    // ERC20 functions

    /**
     * @param amount If this value is uint256(-1) infinite approve
     */
    function approve(address spender, uint256 amount) external override returns (bool) {
        if (amount == uint256(-1)) {
            amount = uint128(-1);
        }
        allowances[msg.sender][spender] = amount.toUint128();
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transferToken(msg.sender, recipient, amount.toUint128());
    }

    /**
     * @notice If allowance amount is uint128(-1), allowance amount is not updated
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        uint128 currentAllowance = allowances[sender][msg.sender];
        if (currentAllowance < amount) {
            return false;
        }
        // Skip if infinity approve
        if (currentAllowance != uint128(-1)) {
            allowances[sender][msg.sender] = uint256(allowances[sender][msg.sender])
                .sub(amount)
                .toUint128();
        }
        _transferToken(sender, recipient, amount.toUint128());
        return true;
    }

    /**
     * @dev Balance is changed by `_updateBalanceData` to reflect correct reward amount
     */
    function _transferToken(
        address from,
        address to,
        uint128 amount
    ) internal returns (bool) {
        if (balance[from].balance < amount) {
            return false;
        }
        _updateBalanceData(from, -1 * int256(amount));
        _updateBalanceData(to, int256(amount));
        emit Transfer(from, to, uint256(amount));
        return true;
    }

    function balanceOf(address user) public view override returns (uint256) {
        return balance[user].balance;
    }

    function totalSupply() public view override returns (uint256) {
        return uint256(shareData[currentTerm].totalShare).sub(totalUnremovedTokens[currentTerm]);
    }

    function getLiquidityReservationData(address user)
        public
        view
        returns (
            uint128 receivedCollateralTerm,
            uint128 receivedCollateralAmount,
            uint128 removeTokenTerm,
            uint128 removeTokenAmount
        )
    {
        return (
            receivedCollaterals[user].term,
            receivedCollaterals[user].value,
            unremovedTokens[user].term,
            unremovedTokens[user].value
        );
    }

    function getCurrentStatus()
        public
        view
        override
        returns (
            uint256 term,
            int16 feeBase,
            uint32 uncheckbondGroupId,
            uint64 unit,
            uint64 trancheTime,
            bool isDanger
        )
    {
        return (
            currentTerm,
            currentFeeBase,
            startBondGroupId,
            priceUnit,
            lastTrancheTime,
            isTotalSupplyDanger
        );
    }

    function getLiquidationData(uint256 term)
        public
        view
        override
        returns (
            bool isLiquidated,
            uint32 liquidatedBondGroupID,
            uint32 endBondGroupId
        )
    {
        if (term == 0) {
            term = currentTerm;
        }
        isLiquidated = liquidationData[term].isLiquidated;
        liquidatedBondGroupID = liquidationData[term].liquidatedBondGroupID;
        endBondGroupId = liquidationData[term].endBondGroupId;
    }

    function totalShareData(uint256 term)
        public
        view
        override
        returns (uint128 totalShare, uint128 totalCollateralPerToken)
    {
        if (term == 0) {
            term = currentTerm;
        }
        return (shareData[term].totalShare, shareData[term].totalCollateralPerToken);
    }

    function getBondGroupIDFromTermAndPrice(uint256 term, uint256 price)
        public
        view
        override
        returns (uint256 bondGroupID)
    {
        price = STRATEGY.calcRoundPrice(price, priceUnit, 1);

        if (term == 0) {
            term = currentTerm;
        }
        return strikePriceToBondGroup[term][price];
    }

    function getInfo()
        public
        view
        override
        returns (
            address bondMaker,
            address strategy,
            address dotc,
            address bondPricerAddress,
            address oracleAddress,
            address rewardTokenAddress,
            address registratorAddress,
            address owner,
            bool reverseOracle,
            uint64 basePriceUnit,
            uint128 maxSupply
        )
    {
        return (
            address(BONDMAKER),
            address(STRATEGY),
            address(DOTC),
            address(BOND_PRICER),
            address(ORACLE),
            address(REWARD_TOKEN),
            address(BOND_REGISTRATOR),
            OWNER,
            REVERSE_ORACLE,
            BASE_PRICE_UNIT,
            uint128(uint128(-1) / (10**uint256(MAX_SUPPLY_DENUMERATOR)))
        );
    }

    function getTermInfo(uint256 term)
        public
        view
        override
        returns (
            uint64 maturity,
            uint64 solidStrikePrice,
            bytes32 SBTID
        )
    {
        if (term == 0) {
            term = currentTerm;
        }
        return (termInfo[term].maturity, termInfo[term].strikePrice, termInfo[term].SBTId);
    }

    /**
     * @notice return user's balance including unsettled share token
     */
    function getExpectedBalance(address user, bool hasReservation)
        external
        view
        override
        returns (uint256 expectedBalance)
    {
        expectedBalance = balance[user].balance;
        if (receivedCollaterals[user].value != 0) {
            hasReservation = true;
            if (currentTerm > receivedCollaterals[msg.sender].term) {
                expectedBalance += _applyDecimalGap(
                    uint256(receivedCollaterals[msg.sender].value).mul(10**decimals).div(
                        uint256(
                            shareData[receivedCollaterals[msg.sender].term + 1]
                                .totalCollateralPerToken
                        )
                    ),
                    true
                );
            }
        }
    }

    /**
     * @notice Return current phase of aggregator
     */
    function getCurrentPhase() public view override returns (AggregatorPhase) {
        if (currentTerm == 0) {
            return AggregatorPhase.BEFORE_START;
        } else if (block.timestamp <= termInfo[currentTerm].maturity) {
            if (block.timestamp <= lastTrancheTime + COOLTIME) {
                return AggregatorPhase.COOL_TIME;
            }
            return AggregatorPhase.ACTIVE;
        } else if (
            block.timestamp > termInfo[currentTerm].maturity &&
            !liquidationData[currentTerm].isLiquidated
        ) {
            return AggregatorPhase.AFTER_MATURITY;
        }
        return AggregatorPhase.EXPIRED;
    }

    /**
     * @notice Calculate expected reward amount at this point
     */
    function getRewardAmount(address user) public view override returns (uint64) {
        return _calcNextReward(balance[user], currentTerm);
    }

    function getTotalRewards() public view override returns (TotalReward[] memory) {
        return totalRewards;
    }

    function isTotalSupplySafe() public view override returns (bool) {
        return !isTotalSupplyDanger;
    }

    function getTotalUnmovedAssets() public view override returns (uint256, uint256) {
        return (totalReceivedCollateral[currentTerm], totalUnremovedTokens[currentTerm]);
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return allowances[owner][spender];
    }

    function getCollateralPerToken(uint256 term) public view override returns (uint256) {
        return shareData[term].totalCollateralPerToken;
    }

    function getBondGroupIdFromStrikePrice(uint256 term, uint256 strikePrice)
        public
        view
        override
        returns (uint256)
    {
        return strikePriceToBondGroup[term][strikePrice];
    }

    function getBalanceData(address user)
        external
        view
        override
        returns (
            uint128 amount,
            uint64 term,
            uint64 rewardAmount
        )
    {
        return (balance[user].balance, balance[user].term, balance[user].rewardAmount);
    }

    /**
     * @notice Get suitable bond groups for current price
     */
    function getIssuableBondGroups() public view override returns (uint256[] memory) {
        return issuableBondGroupIds[currentTerm];
    }
}
