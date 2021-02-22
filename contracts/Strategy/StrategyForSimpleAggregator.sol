// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "../Interfaces/StrategyInterface.sol";
import "../Interfaces/ExchangeInterface.sol";
import "../BondToken_and_GDOTC/bondMaker/BondMakerInterface.sol";
import "../Interfaces/SimpleAggragatorInterface.sol";
import "../BondToken_and_GDOTC/util/Polyline.sol";
// AUDIT-FIX: SFS-01 Not-Fixed: cannot fix
import "../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../node_modules/@openzeppelin/contracts/utils/SafeCast.sol";

contract StrategyForSimpleAggregator is SimpleStrategyInterface, Polyline {
    using SafeMath for uint256;
    using SafeCast for uint256;
    struct FeeInfo {
        int16 currentFeeBase;
        int32 upwardDifference;
        int32 downwardDifference;
    }
    uint256 constant WEEK_LENGTH = 3;
    // AUDIT-FIX: SFS-04 Not-Fixed:
    mapping(bytes32 => address[]) public aggregators;
    mapping(bytes32 => FeeInfo) public feeBases;
    // AUDIT-FIX: SFS-02
    uint256 internal immutable TERM_INTERVAL;
    // AUDIT-FIX: SFS-03
    uint256 internal immutable TERM_CORRECTION_FACTOR;
    int16 constant INITIAL_FEEBASE = 250;

    constructor(uint256 termInterval, uint256 termCF) {
        TERM_INTERVAL = termInterval;
        TERM_CORRECTION_FACTOR = termCF;
    }

    /**
     * @notice Return next maturity.(Default: Friday 3 p.m UTC within 3 weeks )
     */
    function calcNextMaturity() public view override returns (uint256 nextTimeStamp) {
        uint256 week = (block.timestamp - TERM_CORRECTION_FACTOR).div(TERM_INTERVAL);
        nextTimeStamp = ((week + WEEK_LENGTH) * TERM_INTERVAL) + (TERM_CORRECTION_FACTOR);
    }

    /**
     * @notice Determine the bond token amount to be issued/burned.
     * @param issueBondGroupId Bond group ID to be issued
     * @param bondGroupList Determine bond group ID to be burned from this list.
     */
    function getTrancheBonds(
        BondMakerInterface bondMaker,
        address aggregatorAddress,
        uint256 issueBondGroupId,
        uint256 price,
        uint256[] calldata bondGroupList,
        uint64 priceUnit,
        bool isReversedOracle
    )
        public
        view
        virtual
        override
        returns (
            uint256 issueAmount,
            uint256,
            uint256[2] memory IDAndAmountOfBurn
        )
    {
        price = calcRoundPrice(price, priceUnit, 1);
        uint256 baseAmount = _getBaseAmount(SimpleAggregatorInterface(aggregatorAddress));
        for (uint64 i = 0; i < bondGroupList.length; i++) {
            (issueAmount, ) = _getLBTStrikePrice(bondMaker, bondGroupList[i], isReversedOracle);
            // If Call option strike price is different from current price by priceUnit * 5,
            // this bond group becomes target of burn.
            // AUDIT-FIX: SFS-05
            if ((issueAmount > price + priceUnit * 5 || issueAmount < price.sub(priceUnit * 5))) {
                uint256 balance = _getMinBondAmount(bondMaker, bondGroupList[i], aggregatorAddress);
                // If `balance` is larger than that of current target bond group,
                // change the target bond group
                if (balance > baseAmount / 2 && balance > IDAndAmountOfBurn[1]) {
                    IDAndAmountOfBurn[0] = bondGroupList[i];
                    IDAndAmountOfBurn[1] = balance;
                }
            }
        }
        {
            uint256 balance = _getMinBondAmount(bondMaker, issueBondGroupId, aggregatorAddress);
            baseAmount = baseAmount + (IDAndAmountOfBurn[1] / 5);
            if (balance < baseAmount && issueBondGroupId != 0) {
                // AUDIT-FIX: SFS-06
                issueAmount = baseAmount - balance;
            } else {
                issueAmount = 0;
            }
        }
    }

    /**
     * @notice Register feebase for each type of aggregator.
     * Fee base is shared among the same type of aggregators.
     */
    function registerCurrentFeeBase(
        int16 currentFeeBase,
        uint256 currentCollateralPerToken,
        uint256 nextCollateralPerToken,
        address owner,
        address oracleAddress,
        bool isReversedOracle
    ) public override {
        bytes32 aggregatorID = generateAggregatorID(owner, oracleAddress, isReversedOracle);
        int16 feeBase = _calcFeeBase(
            currentFeeBase,
            currentCollateralPerToken,
            nextCollateralPerToken,
            feeBases[aggregatorID].upwardDifference,
            feeBases[aggregatorID].downwardDifference
        );
        address[] memory aggregatorAddresses = aggregators[aggregatorID];
        require(_isValidAggregator(aggregatorAddresses), "sender is invalid aggregator");
        if (feeBase < INITIAL_FEEBASE) {
            feeBases[aggregatorID].currentFeeBase = INITIAL_FEEBASE;
        } else if (feeBase >= 1000) {
            feeBases[aggregatorID].currentFeeBase = 999;
        } else {
            feeBases[aggregatorID].currentFeeBase = feeBase;
        }
    }

    /**
     * @notice If CollateralPerToken amount increases by 5% or more, reduce currentFeeBase by downwardDifference.
     * If CollateralPerToken amount decreases by 5% or more, increase currentFeeBase by upwardDifference.
     */
    function _calcFeeBase(
        int16 currentFeeBase,
        uint256 currentCollateralPerToken,
        uint256 nextCollateralPerToken,
        int32 upwardDifference,
        int32 downwardDifference
    )
        internal
        pure
        returns (
            // AUDIT-FIX: SFS-09
            int16
        )
    {
        // AUDIT-FIX: SFS-07
        if (
            nextCollateralPerToken.mul(100).div(105) > currentCollateralPerToken &&
            currentFeeBase > downwardDifference
        ) {
            return int16(currentFeeBase - downwardDifference);
        } else if (nextCollateralPerToken.mul(105).div(100) < currentCollateralPerToken) {
            // AUDIT-FIX: SFS-08 Not-Fixed: Unnecessary modification: current fee base is under 1000
            return int16(currentFeeBase + upwardDifference);
        }
        return currentFeeBase;
    }

    function _isValidAggregator(address[] memory aggregatorAddresses) internal view returns (bool) {
        for (uint256 i = 0; i < aggregatorAddresses.length; i++) {
            if (aggregatorAddresses[i] == msg.sender) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Register addresses of aggregators for each type of price feed
     * @notice Aggregator owner should register aggregators for fee base registration
     */
    // AUDIT-FIX: SFS-10
    function registerAggregators(
        address oracleAddress,
        bool isReversedOracle,
        address[] calldata aggregatorAddresses,
        int32 upwardDifference,
        int32 downwardDifference
    ) external {
        bytes32 aggregatorID = generateAggregatorID(msg.sender, oracleAddress, isReversedOracle);
        require(aggregators[aggregatorID].length == 0, "This aggregator ID is already registered");
        aggregators[aggregatorID] = aggregatorAddresses;
        feeBases[aggregatorID] = FeeInfo(INITIAL_FEEBASE, upwardDifference, downwardDifference);
    }

    function generateAggregatorID(
        address owner,
        address oracleAddress,
        bool isReversedOracle
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(owner, oracleAddress, isReversedOracle));
    }

    /**
     * @notice Calculate call option price for the current price
     * If reversed oracle is set to aggregator, return reversed strike price
     */
    function calcCallStrikePrice(
        uint256 currentPriceE8,
        uint64 priceUnit,
        bool isReversedOracle
    ) external pure override returns (uint256 callStrikePrice) {
        if (isReversedOracle) {
            callStrikePrice = _getReversedValue(
                calcRoundPrice(currentPriceE8, priceUnit, 1),
                isReversedOracle
            );
        } else {
            callStrikePrice = calcRoundPrice(currentPriceE8, priceUnit, 1);
        }
    }

    /**
     * @notice Determine the valid strike price for the new period.
     * @dev SBT strike price is the half of current price.
     * If reversed oracle is set to aggregator, reversed value is returned.
     */
    function getCurrentStrikePrice(
        uint256 currentPriceE8,
        uint64 priceUnit,
        bool isReversedOracle
    ) external pure override returns (uint256 strikePrice) {
        // AUDIT-FIX: SFS-11
        if (isReversedOracle) {
            strikePrice = _getReversedValue(
                calcRoundPrice(currentPriceE8 * 2, priceUnit, 1),
                isReversedOracle
            );
        } else {
            strikePrice = calcRoundPrice(currentPriceE8, priceUnit, 2);
        }
        return strikePrice;
    }

    function getCurrentSpread(
        address owner,
        address oracleAddress,
        bool isReversedOracle
    ) public view override returns (int16) {
        bytes32 aggregatorID = generateAggregatorID(owner, oracleAddress, isReversedOracle);
        if (feeBases[aggregatorID].currentFeeBase == 0) {
            return INITIAL_FEEBASE;
        }
        return feeBases[aggregatorID].currentFeeBase;
    }

    function _getReversedValue(uint256 value, bool isReversedOracle)
        internal
        pure
        returns (uint256)
    {
        if (!isReversedOracle) {
            return value;
        } else {
            return 10**16 / value;
        }
    }

    /**
     * @dev Calculate base bond amount of issue/burn
     */
    function _getBaseAmount(SimpleAggregatorInterface aggregator) internal view returns (uint256) {
        uint256 collateralAmount = aggregator.getCollateralAmount();
        int16 decimalGap = int16(aggregator.getCollateralDecimal()) - 8;
        return _applyDecimalGap(collateralAmount.div(5), decimalGap);
    }

    function _applyDecimalGap(uint256 amount, int16 decimalGap) internal pure returns (uint256) {
        if (decimalGap < 0) {
            return amount.mul(10**uint256(decimalGap * -1));
        } else {
            return amount / (10**uint256(decimalGap));
        }
    }

    function calcRoundPrice(
        uint256 price,
        uint64 priceUnit,
        uint8 divisor
    ) public pure override returns (uint256 roundedPrice) {
        roundedPrice = price.div(priceUnit * divisor).mul(priceUnit);
    }

    function getFeeInfo(
        address owner,
        address oracleAddress,
        bool isReversedOracle
    )
        public
        view
        returns (
            int16 currentFeeBase,
            int32 upwardDifference,
            int32 downwardDifference
        )
    {
        bytes32 aggregatorID = generateAggregatorID(owner, oracleAddress, isReversedOracle);
        return (
            feeBases[aggregatorID].currentFeeBase,
            feeBases[aggregatorID].upwardDifference,
            feeBases[aggregatorID].downwardDifference
        );
    }

    /**
     * @dev Get LBT strike price in Collateral / USD
     */
    function _getLBTStrikePrice(
        BondMakerInterface bondMaker,
        uint256 bondGroupID,
        bool isReversedOracle
    ) public view returns (uint128, address) {
        (bytes32[] memory bondIDs, ) = bondMaker.getBondGroup(bondGroupID);
        (address bondAddress, , , bytes32 fnMapID) = bondMaker.getBond(bondIDs[1]);
        bytes memory fnMap = bondMaker.getFnMap(fnMapID);
        uint256[] memory zippedLines = decodePolyline(fnMap);
        LineSegment memory secondLine = unzipLineSegment(zippedLines[1]);
        return (
            _getReversedValue(uint256(secondLine.left.x), isReversedOracle).toUint128(),
            bondAddress
        );
    }

    /**
     * @dev Get minimum bond amount in the bond group
     */
    function _getMinBondAmount(
        BondMakerInterface bondMaker,
        uint256 bondGroupID,
        address aggregatorAddress
    ) internal view returns (uint256 balance) {
        (bytes32[] memory bondIDs, ) = bondMaker.getBondGroup(bondGroupID);
        for (uint256 i = 0; i < bondIDs.length; i++) {
            (address bondAddress, , , ) = bondMaker.getBond(bondIDs[i]);
            uint256 bondBalance = IERC20(bondAddress).balanceOf(aggregatorAddress);
            if (i == 0) {
                balance = bondBalance;
            } else if (balance > bondBalance) {
                balance = bondBalance;
            }
        }
    }
}
