// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;
import "../BondToken_and_GDOTC/util/TransferETH.sol";

contract ReserveEth is TransferETH {
    address owner;
    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Error: Only owner can execute this function"
        );
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice Send ETH to user
     * Only aggregator can call this function
     */
    function sendAsset(address payable user, uint256 amount) public onlyOwner {
        _transferETH(user, amount);
    }
}
