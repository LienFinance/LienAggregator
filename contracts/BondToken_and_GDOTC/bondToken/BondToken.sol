// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "../util/TransferETH.sol"; // this contract has payable function
import "../../../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "./BondTokenInterface.sol";

abstract contract BondToken is Ownable, BondTokenInterface, ERC20 {
    using SafeMath for uint256;

    struct Frac128x128 {
        uint128 numerator;
        uint128 denominator;
    }

    Frac128x128 internal _rate;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals
    ) ERC20(name, symbol) {
        _setupDecimals(decimals);
    }

    function mint(address account, uint256 amount)
        public
        virtual
        override
        onlyOwner
        returns (bool success)
    {
        require(!_isExpired(), "this token contract has expired");
        _mint(account, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount)
        public
        override(ERC20, IERC20)
        returns (bool success)
    {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override(ERC20, IERC20) returns (bool success) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            msg.sender,
            allowance(sender, msg.sender).sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    /**
     * @dev Record the settlement price at maturity in the form of a fraction and let the bond
     * token expire.
     */
    function expire(uint128 rateNumerator, uint128 rateDenominator)
        public
        override
        onlyOwner
        returns (bool isFirstTime)
    {
        isFirstTime = !_isExpired();
        if (isFirstTime) {
            _setRate(Frac128x128(rateNumerator, rateDenominator));
        }

        emit LogExpire(rateNumerator, rateDenominator, isFirstTime);
    }

    function simpleBurn(address from, uint256 amount)
        public
        override
        onlyOwner
        returns (bool)
    {
        if (amount > balanceOf(from)) {
            return false;
        }

        _burn(from, amount);
        return true;
    }

    function burn(uint256 amount) public override returns (bool success) {
        if (!_isExpired()) {
            return false;
        }

        _burn(msg.sender, amount);

        if (_rate.numerator != 0) {
            uint8 decimalsOfCollateral = _getCollateralDecimals();
            uint256 withdrawAmount =
                _applyDecimalGap(amount, decimals(), decimalsOfCollateral)
                    .mul(_rate.numerator)
                    .div(_rate.denominator);

            _sendCollateralTo(msg.sender, withdrawAmount);
        }

        return true;
    }

    function burnAll() public override returns (uint256 amount) {
        amount = balanceOf(msg.sender);
        bool success = burn(amount);
        if (!success) {
            amount = 0;
        }
    }

    /**
     * @dev rateDenominator never be zero due to div() function, thus initial _rateDenominator is 0
     * can be used for flag of non-expired;
     */
    function _isExpired() internal view returns (bool) {
        return _rate.denominator != 0;
    }

    function getRate()
        public
        view
        override
        returns (uint128 rateNumerator, uint128 rateDenominator)
    {
        rateNumerator = _rate.numerator;
        rateDenominator = _rate.denominator;
    }

    function _setRate(Frac128x128 memory rate) internal {
        require(
            rate.denominator != 0,
            "system error: the exchange rate must be non-negative number"
        );
        _rate = rate;
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

    function _getCollateralDecimals() internal view virtual returns (uint8);

    function _sendCollateralTo(address receiver, uint256 amount)
        internal
        virtual;
}
