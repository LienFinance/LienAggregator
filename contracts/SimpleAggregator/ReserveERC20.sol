// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;
import "../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract ReserveERC20 {
    using SafeERC20 for IERC20;
    address owner;
    IERC20 collateral;
    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Error: Only owner can execute this function"
        );
        _;
    }

    constructor(IERC20 _collateral) {
        owner = msg.sender;
        collateral = _collateral;
    }

    /**
     * @notice Send collateral ERC20 token to user
     * Only aggregator can call this function
     */
    function sendAsset(address user, uint256 amount) public onlyOwner {
        collateral.safeTransfer(user, amount);
    }
}
