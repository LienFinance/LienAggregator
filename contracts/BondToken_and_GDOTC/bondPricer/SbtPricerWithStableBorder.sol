// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./BondPricerInterface.sol";
import "./CustomGeneralizedPricing.sol";
import "../../../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../util/Time.sol";

contract SbtPricerWithStableBorder is CustomGeneralizedPricing, Ownable, Time {
    using SafeMath for uint256;

    uint16 internal _stableBorderE4;

    event LogUpdateStableBorder(uint16 stableBorderE4);

    constructor(address originalBondPricerAddress, uint16 stableBorderE4)
        CustomGeneralizedPricing(originalBondPricerAddress)
    {
        _updateStableBorder(stableBorderE4);
    }

    function updateStableBorder(uint16 stableBorderE4) external onlyOwner {
        _updateStableBorder(stableBorderE4);
    }

    function getStableBorder() external view returns (uint16 stableBorderE4) {
        stableBorderE4 = _stableBorderE4;
    }

    function _updateStableBorder(uint16 stableBorderE4) internal {
        require(
            stableBorderE4 <= 10**4,
            "stable border must be less than or equal to 1.0000"
        );
        _stableBorderE4 = stableBorderE4;
        emit LogUpdateStableBorder(stableBorderE4);
    }

    function _isAcceptableLbt(
        uint256[] memory,
        int256,
        int256,
        int256,
        uint256,
        uint256
    ) internal pure override returns (bool) {
        _isNotAcceptable();
    }

    function _isAcceptableSbt(
        uint256[] memory,
        int256,
        int256,
        int256,
        uint256,
        uint256
    ) internal pure override returns (bool) {
        _isNotAcceptable();
    }

    function _isAcceptableTriangleBond(
        uint256[] memory,
        int256,
        int256,
        int256,
        uint256,
        uint256
    ) internal pure override returns (bool) {
        _isNotAcceptable();
    }

    function _isAcceptablePureSbt(
        uint256[] memory points,
        int256,
        int256,
        int256 untilMaturity,
        uint256 bondPriceE8,
        uint256
    ) internal view override returns (bool) {
        require(
            untilMaturity <= 12 weeks,
            "the bond maturity must be less than 12 weeks"
        );
        uint256 strikePriceE8 = points[0];
        require(
            bondPriceE8.mul(10**4) >= strikePriceE8.mul(_stableBorderE4),
            "the bond does not meet the stable border"
        );
        return true;
    }

    function _isAcceptableOtherBond(
        uint256[] memory,
        int256,
        int256,
        int256,
        uint256,
        uint256
    ) internal pure override returns (bool) {
        _isNotAcceptable();
    }

    function _isNotAcceptable() internal pure {
        revert("the bond is not pure SBT type");
    }
}
