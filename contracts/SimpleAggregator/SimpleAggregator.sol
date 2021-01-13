// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;
import "../Interfaces/StrategyInterface.sol";
import "../Interfaces/SimpleAggragatorInterface.sol";
import "../Interfaces/ExchangeInterface.sol";
import "../Interfaces/BondTokenInterface.sol";
import "../Interfaces/LatestPriceOracleInterface.sol";
import "../Interfaces/BondPricerInterface.sol";
import "../Interfaces/UseVolatilityOracle.sol";
import "../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";
import "../../node_modules/@openzeppelin/contracts/utils/SafeCast.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

abstract contract SimpleAggregator is
    SimpleAggregatorInterface,
    UseVolatilityOracle
{
    using SafeMath for uint256;
    using SafeMath for uint128;
    using SafeCast for uint256;
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
    }
    struct ShareData {
        uint128 totalShare;
        uint128 totalCollateralPerToken;
    }

    uint256 constant INFINITY = uint256(-1);
    SimpleStrategyInterface STRATEGY;
    ExchangeInterface DOTC;
    BondPricerInterface immutable bondPricer;
    LatestPriceOracleInterface immutable oracle;
    BondMakerInterface immutable bondMaker;

    int16 currentFeeBase;

    mapping(uint256 => bytes32[]) SBT_ID;
    // Todo: Into one struct
    mapping(uint256 => TermInfo) termInfo;

    mapping(uint256 => uint256[]) issuableBondGroupIds;
    // Todo: Into one struct
    mapping(uint256 => LiquidationData) liquidationData;

    mapping(uint256 => mapping(uint256 => bool)) isIssuableBondGroup;

    mapping(uint256 => ShareData) shareData;

    // Todo: Into one struct
    mapping(address => ReceivedCollateral) receivedCollaterals;
    mapping(address => UnRemovedToken) unremovedTokens;
    mapping(address => uint128) balance;
    mapping(address => mapping(address => uint128)) allowances;

    bool isTotalSupplyDanger;
    int16 immutable maxSupplyDenumerator;
    uint32 immutable priceUnit;
    uint8 public constant override decimals = 8;
    string public constant override symbol = "LASH";
    string public constant override name = "LIEN_AGGREGATOR_SHARE";

    mapping(uint256 => uint128) totalReceivedCollateral;
    mapping(uint256 => uint128) totalUnremovedTokens;

    uint256 currentTerm;
    uint8 aggregatorID;

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    event SetAddLiquidity(
        address indexed user,
        uint256 indexed term,
        uint256 collateralAmount
    );
    event SetRemoveLiquidity(
        address indexed user,
        uint256 indexed term,
        uint256 tokenAmount
    );
    event SettleLiquidity(
        address indexed user,
        uint256 indexed term,
        uint256 collateralAmount,
        uint256 tokenAmount
    );

    event AddLiquidity(address indexed user, uint256 tokenAmount);

    modifier isActive() {
        require(
            block.timestamp <= termInfo[currentTerm].maturity,
            "Error: Aggregator is not active"
        );
        _;
    }

    modifier afterMaturity() {
        require(
            block.timestamp > termInfo[currentTerm].maturity,
            "Error: This Function Should Execute After maturity"
        );
        _;
    }

    modifier afterExpired() {
        require(
            liquidationData[currentTerm].isLiquidated || currentTerm == 0,
            "Error: This Function Should Execute After Expired"
        );
        _;
    }

    modifier isSafeSupply() {
        require(!isTotalSupplyDanger, "TotalSupply is unsafe");
        _;
    }

    constructor(
        BondMakerInterface _bondMaker,
        LatestPriceOracleInterface _oracle,
        BondPricerInterface _pricer,
        SimpleStrategyInterface strategy,
        address exchangeAddress,
        int16 _maxSupplyDenumerator,
        uint32 _priceUnit,
        VolatilityOracleInterface _volOracle
    ) UseVolatilityOracle(_volOracle) {
        bondMaker = _bondMaker;
        STRATEGY = strategy;
        bondPricer = _pricer;
        oracle = _oracle;
        priceUnit = _priceUnit;
        DOTC = ExchangeInterface(exchangeAddress);
        maxSupplyDenumerator = _maxSupplyDenumerator;
    }

    function addIssuableBondGroup(uint256 bondGroupId) public override {
        uint256 currentPrice = oracle.latestPrice();
        bool isOk = STRATEGY.isValidLBT(
            bondMaker,
            bondGroupId,
            currentPrice,
            termInfo[currentTerm].strikePrice,
            termInfo[currentTerm].maturity,
            priceUnit
        );
        require(isOk, "Error: Invalid BondGroup");
        require(
            !isIssuableBondGroup[currentTerm][bondGroupId],
            "Error: This BondGroup is already issuable"
        );
        issuableBondGroupIds[currentTerm].push(bondGroupId);
        isIssuableBondGroup[currentTerm][bondGroupId] = true;

        (bytes32[] memory bondIDs, ) = bondMaker.getBondGroup(bondGroupId);
        (address bondType1Address, , , ) = bondMaker.getBond(bondIDs[1]);

        if (
            IERC20(bondType1Address).allowance(address(this), address(DOTC)) ==
            0
        ) {
            IERC20(bondType1Address).approve(address(DOTC), INFINITY);
        }

        (address bondType2Address, , , ) = bondMaker.getBond(bondIDs[2]);

        if (
            IERC20(bondType2Address).allowance(address(this), address(DOTC)) ==
            0
        ) {
            IERC20(bondType2Address).approve(address(DOTC), INFINITY);
        }
        (address bondType3Address, , , ) = bondMaker.getBond(bondIDs[3]);
        if (
            IERC20(bondType3Address).allowance(address(this), address(DOTC)) ==
            0
        ) {
            IERC20(bondType3Address).approve(address(DOTC), INFINITY);
        }
    }

    function renewMaturity() public override afterExpired {
        uint256 totalUnsentTokens;
        uint256 ethPerTokenE8;
        // TODO: if aggregators length is 0 and totalShare[currentTerm] > 0
        if (shareData[currentTerm].totalShare > 0) {
            uint256 collateralAmount = _getCollateralAmount();
            totalUnsentTokens = uint256(shareData[currentTerm].totalShare)
                .mul(totalReceivedCollateral[currentTerm])
                .div(collateralAmount);
            ethPerTokenE8 = _applyDecimalGap(
                collateralAmount.mul(10**decimals).div(
                    shareData[currentTerm].totalShare
                ),
                true
            );
        } else if (totalReceivedCollateral[currentTerm] > 0) {
            totalUnsentTokens = _applyDecimalGap(
                totalReceivedCollateral[currentTerm],
                true
            );
            ethPerTokenE8 = 10**8;
        }

        uint256 _totalSupply = shareData[currentTerm].totalShare +
            totalUnsentTokens;
        shareData[currentTerm + 1].totalCollateralPerToken = ethPerTokenE8.toUint128();
        shareData[currentTerm + 1].totalShare = uint256(
            shareData[currentTerm]
                .totalShare
        )
            .add(totalUnsentTokens)
            .sub(totalUnremovedTokens[currentTerm])
            .toUint128();

        if (
            shareData[currentTerm + 1].totalShare >
            uint128(-1) / 10**uint128(maxSupplyDenumerator)
        ) {
            isTotalSupplyDanger = true;
        }

        uint256 reserveAmountRatioE8 = uint256(
            totalUnremovedTokens[currentTerm]
        )
            .mul(10**decimals)
            .div(_totalSupply);
        _reserveAsset(reserveAmountRatioE8);
        _updateBondGroupData();
    }

    function _updateBondGroupData() internal {
        uint256 nextTimeStamp = STRATEGY.calcNextMaturity();
        uint256 currentStrikePrice = STRATEGY.getCurrentStrikePrice(
            nextTimeStamp,
            oracle.latestPrice(),
            _getVolatility(nextTimeStamp),
            priceUnit
        );
        currentTerm += 1;
        TermInfo memory newTermInfo = TermInfo(
            nextTimeStamp.toUint64(),
            currentStrikePrice.toUint64()
        );
        termInfo[currentTerm] = newTermInfo;
    }

    function _addLiquidity(uint256 amount) internal returns (bool success) {
        settleTokens();
        if (receivedCollaterals[msg.sender].value == 0) {
            receivedCollaterals[msg.sender].term = uint128(currentTerm);
            receivedCollaterals[msg.sender].value = uint128(amount);
            totalReceivedCollateral[currentTerm] += amount.toUint128();
            emit SetAddLiquidity(msg.sender, currentTerm, amount);
            return true;
        } else if (receivedCollaterals[msg.sender].term == currentTerm) {
            receivedCollaterals[msg.sender].value += uint128(amount);
            totalReceivedCollateral[currentTerm] += amount.toUint128();
            emit SetAddLiquidity(msg.sender, currentTerm, amount);
            return true;
        }
        return false;
    }

    function approve(address spender, uint256 amount)
        external
        override
        returns (bool)
    {
        if (amount == uint256(-1)) {
            amount = uint128(-1);
        }
        allowances[msg.sender][spender] = amount.toUint128();
        emit Approval(msg.sender, spender, amount);
    }

    function transfer(address recipient, uint256 amount)
        external
        override
        returns (bool)
    {
        return _transferToken(msg.sender, recipient, amount.toUint128());
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        uint128 allowance = allowances[sender][msg.sender];
        if (allowance < amount) {
            return false;
        }
        if (allowance != uint128(-1)) {
            allowances[sender][msg.sender] = uint256(
                allowances[sender][msg.sender]
            )
                .sub(amount)
                .toUint128();
        }
        _transferToken(sender, recipient, amount.toUint128());
    }

    function _transferToken(
        address from,
        address to,
        uint128 amount
    ) internal returns (bool) {
        if (balance[from] < amount) {
            return false;
        }
        balance[from] = uint256(balance[from]).sub(amount).toUint128();
        balance[to] = uint256(balance[to]).add(amount).toUint128();
        emit Transfer(from, to, uint256(amount));
        return true;
    }

    function removeLiquidity(uint128 amount)
        external
        override
        returns (bool success)
    {
        settleTokens();
        if (unremovedTokens[msg.sender].value == 0) {
            balance[msg.sender] = uint128(
                uint256(balance[msg.sender]).sub(amount)
            );
            unremovedTokens[msg.sender].term = uint128(currentTerm);
            unremovedTokens[msg.sender].value = amount;
            totalUnremovedTokens[currentTerm] += amount;
            emit SetRemoveLiquidity(msg.sender, currentTerm, amount);
            return true;
        }
        return false;
    }

    function settleTokens()
        public
        override
        returns (uint256 unsentETH, uint256 unsentToken)
    {
        if (currentTerm == 0) {
            return (0, 0);
        }

        if (
            unremovedTokens[msg.sender].value != 0 &&
            currentTerm > unremovedTokens[msg.sender].term
        ) {
            unsentETH = _applyDecimalGap(
                uint256(unremovedTokens[msg.sender].value)
                    .mul(
                    shareData[uint256(unremovedTokens[msg.sender].term + 1)]
                        .totalCollateralPerToken
                )
                    .div(10**decimals),
                false
            );
            if (unsentETH > 0) {
                _sendTokens(msg.sender, unsentETH);
            }
            delete unremovedTokens[msg.sender];
        }

        if (
            receivedCollaterals[msg.sender].value != 0 &&
            currentTerm > receivedCollaterals[msg.sender].term
        ) {
            unsentToken = _applyDecimalGap(
                uint256(receivedCollaterals[msg.sender].value).mul(10**decimals).div(
                    uint256(
                        shareData[receivedCollaterals[msg.sender].term + 1]
                            .totalCollateralPerToken
                    )
                ),
                true
            );
            balance[msg.sender] = uint256(balance[msg.sender])
                .add(unsentToken)
                .toUint128();
            delete receivedCollaterals[msg.sender];
        }
        emit SettleLiquidity(msg.sender, currentTerm, unsentETH, unsentToken);
    }

    function addIssuableBondGroups(uint256[] memory bondGroupIds)
        public
        override
    {
        for (uint256 i; i < bondGroupIds.length; i++) {
            addIssuableBondGroup(bondGroupIds[i]);
        }
    }

    function liquidateBonds() public override afterMaturity {
        require(
            !liquidationData[currentTerm].isLiquidated,
            "Error: All Bonds Have Been Expired"
        );
        if (liquidationData[currentTerm].endBondGroupId == 0) {
            liquidationData[currentTerm].endBondGroupId = bondMaker
                .nextBondGroupID()
                .toUint32();
        }
        uint32 endIndex;
        uint32 startIndex;
        uint32 liquidateBondNumber;
        uint64 maturity = termInfo[currentTerm].maturity;
        uint64 priviousMaturity = termInfo[currentTerm - 1].maturity;
        {
            uint256 ethAllowance = DOTC.ethAllowance(address(this));
            if (ethAllowance > 0) {
                DOTC.withdrawEth();
            }
        }

        if (liquidationData[currentTerm].liquidatedBondGroupID == 0) {
            startIndex = 1;
        } else {
            startIndex = liquidationData[currentTerm].liquidatedBondGroupID;
        }

        if (liquidationData[currentTerm].endBondGroupId - startIndex > 50) {
            endIndex = startIndex + 50;
            liquidationData[currentTerm].liquidatedBondGroupID = endIndex;
        } else {
            endIndex = liquidationData[currentTerm].endBondGroupId;
        }

        for (uint256 i = startIndex; i < endIndex; i++) {
            liquidateBondNumber = _liquidateBondGroup(
                i,
                liquidateBondNumber,
                maturity,
                priviousMaturity
            );

            if (liquidateBondNumber > 9) {
                if (i == endIndex - 1) {
                    liquidationData[currentTerm].isLiquidated = true;
                } else {
                    liquidationData[currentTerm].liquidatedBondGroupID = uint32(
                        i + 1
                    );
                }
                return;
            }
        }

        if (endIndex == liquidationData[currentTerm].endBondGroupId) {
            liquidationData[currentTerm].isLiquidated = true;
        } else {
            liquidationData[currentTerm].liquidatedBondGroupID = uint32(
                endIndex
            );
        }
    }

    function _liquidateBondGroup(
        uint256 bondGroupId,
        uint32 liquidateBondNumber,
        uint64 maturity,
        uint64 priviousMaturity
    ) internal returns (uint32) {
        (bytes32[] memory bondIds, uint256 _maturity) = bondMaker.getBondGroup(
            bondGroupId
        );
        if (
            _maturity > maturity ||
            (_maturity < priviousMaturity && priviousMaturity != 0)
        ) {
            return liquidateBondNumber;
        }
        for (uint256 i = 0; i < bondIds.length; i++) {
            (address bondAddress, , , ) = bondMaker.getBond(bondIds[i]);
            liquidateBondNumber = _burnBond(bondAddress, liquidateBondNumber);
        }
        return liquidateBondNumber;
    }

    function trancheBonds() external override isActive {
        int256[] memory issueBonds = STRATEGY.getTrancheBonds(
            bondMaker,
            address(this),
            oracle.latestPrice(),
            issuableBondGroupIds[currentTerm],
            priceUnit
        );

        if (issueBonds[0] > 0) {
            DOTC.depositEth{value: uint256(issueBonds[0])}();
        }

        for (uint256 i = 0; i < (issueBonds.length - 1) / 2; i++) {
            if (issueBonds[(i + 1) * 2] > 0) {
                _issueBonds(
                    uint256(issueBonds[(i + 1) * 2 - 1]),
                    uint256(issueBonds[(i + 1) * 2])
                );
            } else if (issueBonds[(i + 1) * 2] < 0) {
                require(
                    bondMaker.reverseBondGroupToCollateral(
                        uint256(issueBonds[(i + 1) * 2 - 1]),
                        uint256(issueBonds[(i + 1) * 2] * -1)
                    ),
                    "Error: Could Reverse LBTs to collateral"
                );
            }
        }
    }

    function _burnBond(address bondAddress, uint32 liquidateBondNumber)
        internal
        returns (uint32)
    {
        BondTokenInterface bond = BondTokenInterface(bondAddress);
        if (bond.balanceOf(address(this)) > 0) {
            bond.burnAll();
            liquidateBondNumber += 1;
        }
        return liquidateBondNumber;
    }

    function getIssuableBondGroups() public view returns (uint256[] memory) {
        return issuableBondGroupIds[currentTerm];
    }

    function getIsLiquidated(uint256 term) public view returns (bool) {
        if (term == INFINITY) {
            term = currentTerm;
        }
        return liquidationData[term].isLiquidated;
    }

    function isIssuableGroupID(uint256 bondGroupID, uint256 term)
        public
        view
        returns (bool)
    {
        if (term == INFINITY) {
            term = currentTerm;
        }
        return isIssuableBondGroup[term][bondGroupID];
    }

    function getInfo()
        public
        view
        returns (
            address strategy,
            address dotc,
            address bondPricerAddress,
            address oracleAddress,
            uint256 maturity,
            uint256 solidStrikePrice,
            uint256 term,
            int16 feebase,
            uint32 priceunit
        )
    {
        return (
            address(STRATEGY),
            address(DOTC),
            address(bondPricer),
            address(oracle),
            termInfo[currentTerm].maturity,
            termInfo[currentTerm].strikePrice,
            currentTerm,
            currentFeeBase,
            priceUnit
        );
    }

    function _applyDecimalGap(uint256 amount, bool isDiv)
        internal
        view
        virtual
        returns (uint256)
    {}

    function _sendTokens(address user, uint256 amount) internal virtual {}

    function _issueBonds(uint256 bondgroupID, uint256 amount)
        internal
        virtual
    {}

    function getCollateralDecimal()
        external
        view
        virtual
        override
        returns (int16)
    {}

    function isEthAggregator() external pure virtual override returns (bool) {}

    function getReserveAddress() external view virtual returns (address) {}

    function _getCollateralAmount() internal view virtual returns (uint256) {}

    function getCollateralAmount()
        external
        view
        virtual
        override
        returns (uint256)
    {}

    function _reserveAsset(uint256 reserveAmountRatioE8) internal virtual {}

    function isTotalSupplySafe() public view returns (bool) {
        return !isTotalSupplyDanger;
    }

    function getTotalUnmovedAssets() public view returns (uint256, uint256) {
        return (
            totalReceivedCollateral[currentTerm],
            totalUnremovedTokens[currentTerm]
        );
    }

    function totalSupply() public view override returns (uint256) {
        return
            uint256(shareData[currentTerm].totalShare).sub(
                totalUnremovedTokens[currentTerm]
            );
    }

    function totalSupplyTermOf(uint256 term) public view returns (uint256) {
        return shareData[term].totalShare;
    }

    function balanceOf(address user) public view override returns (uint256) {
        return balance[user];
    }

    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return allowances[owner][spender];
    }

    function getCollateralPerToken(uint256 term) public view returns (uint256) {
        return shareData[term].totalCollateralPerToken;
    }
}
