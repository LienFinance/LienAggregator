// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "../Pricing/DetectBondShape.sol";
import "../Pricing/GeneralizedPricing.sol";
import "../Interfaces/StrategyInterface.sol";
import "../Interfaces/ExchangeInterface.sol";
import "../Interfaces/BondMakerInterface.sol";
import "../Interfaces/SimpleAggragatorInterface.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StrategyForSimpleAggregator is
    SimpleStrategyInterface,
    DetectBondShape,
    GeneralizedPricing
{
    using SafeMath for uint256;
    uint256 constant WEEK_LENGTH = 3;
    ExchangeInterface immutable exchange;
    uint256 immutable TERM_INTERVAL;
    uint256 immutable TERM_CORRECTION_FACTOR;

    constructor(
        ExchangeInterface _exchange,
        uint256 termInterval,
        uint256 termCF
    ) {
        exchange = _exchange;
        TERM_INTERVAL = termInterval;
        TERM_CORRECTION_FACTOR = termCF;
    }

    function calcNextMaturity()
        public
        view
        override
        returns (uint256 nextTimeStamp)
    {
        uint256 week = block.timestamp.div(TERM_INTERVAL);
        nextTimeStamp =
            ((week + WEEK_LENGTH) * TERM_INTERVAL) +
            (TERM_CORRECTION_FACTOR);
    }

    function isValidLBT(
        BondMakerInterface bondMaker,
        uint256 bondGroupID,
        uint256 currentPrice,
        uint256 solidStrikePrice,
        uint256 maturity,
        uint32 priceUnit
    ) external view override returns (bool) {
        currentPrice = _calcRoundPrice(currentPrice, priceUnit, 1);
        (bytes32[] memory bondIDs, uint256 _maturity) = bondMaker.getBondGroup(
            bondGroupID
        );

        if (maturity != _maturity || bondIDs.length != 4) {
            return false;
        }

        (, , uint256 _solidStrikePrice, bytes32 fnMapID) = bondMaker.getBond(
            bondIDs[0]
        );

        if (_solidStrikePrice == 0 || _solidStrikePrice != solidStrikePrice) {
            return false;
        }

        (, , , fnMapID) = bondMaker.getBond(bondIDs[1]);
        bytes memory fnMap = bondMaker.getFnMap(fnMapID);
        (bool isLBT, uint256[] memory LBTPoints) = _isLBTShape(fnMap);
        if (
            !isLBT ||
            ((LBTPoints[1] - LBTPoints[0]) != LBTPoints[2] &&
                LBTPoints[2] % priceUnit != 0)
        ) {
            return false;
        }

        (, , , fnMapID) = bondMaker.getBond(bondIDs[2]);
        fnMap = bondMaker.getFnMap(fnMapID);
        (bool isLev2, uint256[] memory lev2Points) = _isSBTShape(fnMap);
        // TODO:
        if (
            !isLev2 ||
            lev2Points[0] >= LBTPoints[0] ||
            lev2Points[1] <= LBTPoints[0] ||
            lev2Points[1] >
            LBTPoints[0] * 2 - solidStrikePrice + priceUnit * 2 ||
            lev2Points[1] < LBTPoints[0] * 2 - solidStrikePrice - priceUnit * 2
        ) {
            return false;
        }

        (, , , fnMapID) = bondMaker.getBond(bondIDs[3]);
        fnMap = bondMaker.getFnMap(fnMapID);
        (bool isVolShort, uint256[] memory volShortPoints) = _isTriangle(fnMap);
        if (
            !isVolShort ||
            volShortPoints[0] != solidStrikePrice ||
            volShortPoints[1] != LBTPoints[0] ||
            volShortPoints[3] != lev2Points[1]
        ) {
            return false;
        }

        return true;
    }

    function getTrancheBonds(
        BondMakerInterface bondMaker,
        address aggregatorAddress,
        uint256 price,
        uint256[] calldata bondGroupList,
        uint32 priceUnit
    ) external view override returns (int256[] memory bonds) {
        bonds = new int256[](bondGroupList.length * 2 + 1);

        if (SimpleAggregatorInterface(aggregatorAddress).isEthAggregator()) {
            uint256 currentDepositAmount = exchange.ethAllowance(
                aggregatorAddress
            );
            uint256 baseETHAmount = aggregatorAddress.balance.div(10);
            if (currentDepositAmount < baseETHAmount) {
                bonds[0] = int256(baseETHAmount.sub(currentDepositAmount));
            } else {
                bonds[0] = 0;
            }
        } else {
            bonds[0] = 0;
        }

        price = _calcRoundPrice(price, priceUnit, 1);
        uint256 baseAmount = _getBaseAmount(
            SimpleAggregatorInterface(aggregatorAddress)
        );
        bool isReversedLBT;
        for (uint256 i = 0; i < bondGroupList.length; i++) {
            (uint256 LBTStrikePrice, address LBTAddress) = _getLBTStrikePrice(
                bondMaker,
                bondGroupList[i]
            );
            // TODO: If no suitable bondgroup, best bg will tranche
            if (
                LBTStrikePrice <= price + priceUnit &&
                LBTStrikePrice > price - priceUnit
            ) {
                uint256 balance = IERC20(LBTAddress).balanceOf(
                    aggregatorAddress
                );
                if (balance < baseAmount) {
                    bonds[i * 2 + 1] = int256(bondGroupList[i]);
                    bonds[(i + 1) * 2] = int256(baseAmount.sub(balance));
                } else {
                    bonds[i * 2 + 1] = int256(bondGroupList[i]);
                    bonds[(i + 1) * 2] = 0;
                }
            } else if (
                (LBTStrikePrice > price + priceUnit * 5 ||
                    LBTStrikePrice < price - priceUnit * 5) && !isReversedLBT
            ) {
                uint256 balance = _getMinBondAmount(
                    bondMaker,
                    bondGroupList[i],
                    aggregatorAddress
                );
                if (balance > baseAmount / 2) {
                    bonds[i * 2 + 1] = int256(bondGroupList[i]);
                    bonds[(i + 1) * 2] = int256(balance) * -1;
                    isReversedLBT = true;
                } else {
                    bonds[i * 2 + 1] = int256(bondGroupList[i]);
                    bonds[(i + 1) * 2] = 0;
                }
            } else {
                bonds[i * 2 + 1] = int256(bondGroupList[i]);
                bonds[(i + 1) * 2] = 0;
            }
        }
    }

    function getCurrentStrikePrice(
        uint256 maturity,
        uint256 currentPriceE8,
        uint256 volatilityE8,
        uint32 priceUnit
    ) external view override returns (uint256) {
        uint256 strikePrice = _calcRoundPrice(currentPriceE8, priceUnit, 2);
        uint64[] memory points = new uint64[](1);
        while (true) {
            points[0] = uint64(strikePrice);
            (uint256 SBTPrice, ) = _calcPureSBTPrice(
                points,
                int256(currentPriceE8),
                int256(volatilityE8),
                int256(maturity.sub(block.timestamp))
            );
            if (SBTPrice >= strikePrice.mul(95).div(100)) {
                break;
            } else {
                strikePrice = strikePrice.sub(priceUnit);
            }
        }
        return strikePrice;
    }

    function getCurrentSpread() external pure override returns (int16) {
        return 50;
    }

    function _getBaseAmount(SimpleAggregatorInterface aggregator)
        internal
        view
        returns (uint256)
    {
        uint256 collateralAmount = aggregator.getCollateralAmount();
        int16 decimalGap = int16(aggregator.getCollateralDecimal() - 8);
        return _applyDecimalGap(collateralAmount.div(5), decimalGap);
    }

    function _applyDecimalGap(uint256 amount, int16 decimalGap)
        internal
        pure
        returns (uint256)
    {
        if (decimalGap > 0) {
            return amount.div(10**uint256(decimalGap));
        } else {
            return amount.mul(10**uint256(decimalGap * -1));
        }
    }

    function _calcRoundPrice(
        uint256 price,
        uint32 priceUnit,
        uint8 baseUnit
    ) internal pure returns (uint256 roundedPrice) {
        roundedPrice = price.div(priceUnit * baseUnit).mul(priceUnit);
    }

    function _getLBTStrikePrice(
        BondMakerInterface bondMaker,
        uint256 bondGroupID
    ) public view returns (uint256, address) {
        (bytes32[] memory bondIDs, ) = bondMaker.getBondGroup(bondGroupID);
        (address bondAddress, , , bytes32 fnMapID) = bondMaker.getBond(
            bondIDs[1]
        );
        bytes memory fnMap = bondMaker.getFnMap(fnMapID);
        uint256[] memory zippedLines = decodePolyline(fnMap);
        uint64[4] memory secondLine = unzipLineSegment(zippedLines[1]);
        return (uint256(secondLine[0]), bondAddress);
    }

    function _getMinBondAmount(
        BondMakerInterface bondMaker,
        uint256 bondGroupID,
        address aggregatorAddress
    ) internal view returns (uint256 balance) {
        (bytes32[] memory bondIDs, ) = bondMaker.getBondGroup(bondGroupID);
        for (uint256 i = 0; i < bondIDs.length; i++) {
            (address bondAddress, , , ) = bondMaker.getBond(bondIDs[i]);
            uint256 bondBalance = IERC20(bondAddress).balanceOf(
                aggregatorAddress
            );
            if (balance > bondBalance || balance == 0) {
                balance = bondBalance;
            }
        }
    }
}
