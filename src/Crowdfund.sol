// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.36;

import {Ownable} from "solady/src/auth/Ownable.sol";

contract Crowdfund is Ownable {
    uint256 public immutable targetAmount;

    uint256 public amountReceived;

    mapping(address => uint256) public contributions;

    event Contribution(address indexed contributor, uint256 indexed amount);

    error TargetAmountReached();

    constructor(address owner_, uint256 targetAmount_) {
        _initializeOwner(owner_);
        targetAmount = targetAmount_;
    }

    modifier whenTargetNotReached() {
        if (amountReceived >= targetAmount) revert TargetAmountReached();
        _;
    }

    receive() external payable {
        contribute();
    }

    function contribute() public payable whenTargetNotReached {
        amountReceived += msg.value;
        contributions[msg.sender] += msg.value;
        emit Contribution(msg.sender, msg.value);
    }
}
