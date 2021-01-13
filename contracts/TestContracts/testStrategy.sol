pragma solidity >=0.6.6;
import "../Interfaces/StrategyInterface.sol";
import "../Interfaces/BondMakerInterface.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestStrategy2 is StrategyInterface {
    int16 spread = 100;

    function isValidBondGroup(
        BondMakerInterface bm,
        uint256 bondGroupId,
        uint256 currentStrikePrice,
        uint256 nextTimeStamp
    ) external view override returns (bool) {
        (bytes32[] memory bondIDs, uint256 maturity) = bm.getBondGroup(
            bondGroupId
        );
        (, , uint256 solidStrikePrice, ) = bm.getBond(bondIDs[0]);
        require(bondIDs.length == 2, "Invalid bondlength");
        require(currentStrikePrice == solidStrikePrice, "Invalid strike price");
        return (bondIDs.length == 2 &&
            nextTimeStamp == maturity &&
            currentStrikePrice == solidStrikePrice);
    }

    function isValidLBT(
        BondMakerInterface bm,
        uint256 bondGroupId,
        uint256 currentPrice,
        uint256 solidStrikePrice,
        uint256 maturity
    ) external view override returns (bool) {
        (bytes32[] memory bondIDs, uint256 _maturity) = bm.getBondGroup(
            bondGroupId
        );
        (, , uint256 _solidStrikePrice, ) = bm.getBond(bondIDs[0]);
        return (bondIDs.length == 4 &&
            maturity == _maturity &&
            solidStrikePrice == _solidStrikePrice);
    }

    function getTrancheBonds(
        BondMakerInterface bm,
        address aggregatorAddress,
        uint256 baseBondGroupID,
        uint256 price,
        uint256[] calldata bondGroupList
    ) external view override returns (int256[] memory) {
        int256[] memory amounts = new int256[](bondGroupList.length * 2 + 1);
        amounts[0] = int256(aggregatorAddress.balance / 10);
        if (bondGroupList.length > 0) {
            (bytes32[] memory baseBondIds, ) = bm.getBondGroup(
                bondGroupList[0]
            );
            (address baseLBT, , , ) = bm.getBond(baseBondIds[1]);
            uint256 balance = IERC20(baseLBT).balanceOf(aggregatorAddress);
            for (uint256 i = 0; i < bondGroupList.length; i++) {
                amounts[(i + 1) * 2 - 1] = int256(bondGroupList[i]);
                amounts[(i + 1) * 2] = int256(
                    balance / bondGroupList.length / 2
                );
            }
        }
        return amounts;
    }

    function getCurrentStrikePrice(
        uint256 maturity,
        uint256 currentPriceE8,
        uint256 volatilityE8
    ) external view override returns (uint256) {
        return 20000000000;
    }

    function getCurrentSpread() external view override returns (int16) {
        return spread;
    }

    function changeSpread(int16 newSpread) public {
        spread = newSpread;
    }

    function calcNextMaturity() public view returns (uint256 nextTimeStamp) {
        uint256 WeekInSec = 608000;
        uint256 week = block.timestamp / (WeekInSec);
        nextTimeStamp = ((week + 3) * WeekInSec) + (144000);
    }
}

contract MockSimpleStrategy2 is SimpleStrategyInterface {
    int16 spread = 100;

    function isValidLBT(
        BondMakerInterface bm,
        uint256 bondGroupId,
        uint256 currentPrice,
        uint256 solidStrikePrice,
        uint256 maturity,
        uint32 priceUnit
    ) external view override returns (bool) {
        (bytes32[] memory bondIDs, uint256 _maturity) = bm.getBondGroup(
            bondGroupId
        );
        (, , uint256 _solidStrikePrice, ) = bm.getBond(bondIDs[0]);
        return (bondIDs.length == 4 &&
            maturity == _maturity &&
            solidStrikePrice == _solidStrikePrice);
    }

    function getTrancheBonds(
        BondMakerInterface bm,
        address aggregatorAddress,
        uint256 price,
        uint256[] calldata bondGroupList,
        uint32 priceUnit
    ) external view override returns (int256[] memory) {
        int256[] memory amounts = new int256[](bondGroupList.length * 2 + 1);
        amounts[0] = int256(aggregatorAddress.balance / 10);
        if (bondGroupList.length > 0) {
            (bytes32[] memory baseBondIds, ) = bm.getBondGroup(
                bondGroupList[0]
            );
            (address baseLBT, , , ) = bm.getBond(baseBondIds[1]);
            uint256 balance = IERC20(baseLBT).balanceOf(aggregatorAddress);
            for (uint256 i = 0; i < bondGroupList.length; i++) {
                amounts[(i + 1) * 2 - 1] = int256(bondGroupList[i]);
                amounts[(i + 1) * 2] = int256(
                    balance / bondGroupList.length / 2
                );
            }
        }
        return amounts;
    }

    function getCurrentStrikePrice(
        uint256 maturity,
        uint256 currentPriceE8,
        uint256 volatilityE8,
        uint32 priceUnit
    ) external view override returns (uint256) {
        return 20000000000;
    }

    function getCurrentSpread() external view override returns (int16) {
        return spread;
    }

    function changeSpread(int16 newSpread) public {
        spread = newSpread;
    }

    function calcNextMaturity()
        public
        view
        override
        returns (uint256 nextTimeStamp)
    {
        uint256 WeekInSec = 608000;
        uint256 week = block.timestamp / (WeekInSec);
        nextTimeStamp = ((week + 3) * WeekInSec) + (144000);
    }
}
