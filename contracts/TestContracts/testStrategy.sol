// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;
import "../Interfaces/StrategyInterface.sol";
import "../BondToken_and_GDOTC/bondMaker/BondMakerInterface.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockSimpleStrategy2 is SimpleStrategyInterface {
    int16 spread = 250;

    function getTrancheBonds(
        BondMakerInterface bm,
        address aggregatorAddress,
        uint256 issueBondGroupId,
        uint256,
        uint256[] calldata bondGroupList,
        uint64,
        bool
    )
        external
        view
        override
        returns (
            uint256 issueAmount,
            uint256 ethAmount,
            uint256[2] memory
        )
    {
        ethAmount = aggregatorAddress.balance / 10;
        if (bondGroupList.length > 0) {
            (bytes32[] memory baseBondIds, ) = bm.getBondGroup(issueBondGroupId);
            (address baseLBT, , , ) = bm.getBond(baseBondIds[1]);
            uint256 balance = IERC20(baseLBT).balanceOf(aggregatorAddress);
            issueAmount = (aggregatorAddress.balance / 5) - balance;
        }
    }

    function getCurrentStrikePrice(
        uint256,
        uint64,
        bool isReversedOracle
    ) external pure override returns (uint256) {
        if (isReversedOracle) {
            return 125000;
        }
        return 200 * 10**8;
    }

    function registerCurrentFeeBase(
        int16 feeBase,
        uint256,
        uint256,
        address,
        address,
        bool
    ) public override {
        spread = feeBase;
    }

    function getCurrentSpread(
        address,
        address,
        bool
    ) public view override returns (int16) {
        return spread;
    }

    function changeSpread(int16 newSpread) public {
        spread = newSpread;
    }

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

    function calcRoundPrice(
        uint256 price,
        uint64 priceUnit,
        uint8 divisor
    ) public pure override returns (uint256 roundedPrice) {
        roundedPrice = (price / (priceUnit * divisor)) * (priceUnit);
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

    function calcNextMaturity() public view override returns (uint256 nextTimeStamp) {
        uint256 WeekInSec = 604800;
        uint256 week = (block.timestamp - 144000) / (WeekInSec);
        nextTimeStamp = ((week + 3) * WeekInSec) + (144000);
    }
}
