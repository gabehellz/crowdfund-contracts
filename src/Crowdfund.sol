// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.36;

import {Ownable} from "solady/src/auth/Ownable.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";

contract Crowdfund is Ownable {
    uint256 public immutable targetEthAmount;

    uint256 public immutable targetUsdAmount;

    uint256 public amountEthReceived;

    uint256 public amountUsdReceived;

    address public weth;

    address public usdc;

    mapping(address => uint256) public contributionsEth;

    mapping(address => uint256) public contributionsWeth;

    mapping(address => uint256) public contributionsUsd;

    event Contribution(address indexed contributor, address indexed token, uint256 indexed amount);

    error TargetEthAmountReached();

    error TargetUsdAmountReached();

    constructor(address owner_, address weth_, address usdc_, uint256 targetEthAmount_, uint256 targetUsdAmount_) {
        _initializeOwner(owner_);
        weth = weth_;
        usdc = usdc_;
        targetEthAmount = targetEthAmount_;
        targetUsdAmount = targetUsdAmount_;
    }

    modifier whenTargetEthNotReached() {
        if (amountEthReceived >= targetEthAmount) revert TargetEthAmountReached();
        _;
    }

    modifier whenTargetUsdNotReached() {
        if (amountUsdReceived >= targetUsdAmount) revert TargetUsdAmountReached();
        _;
    }

    receive() external payable {
        contribute();
    }

    function contribute() public payable whenTargetEthNotReached {
        amountEthReceived += msg.value;
        contributionsEth[msg.sender] += msg.value;
        emit Contribution(msg.sender, address(0), msg.value);
    }

    function contributeWrapped(uint256 amount) external whenTargetEthNotReached {
        amountEthReceived += amount;
        contributionsWeth[msg.sender] += amount;
        SafeTransferLib.safeTransferFrom(weth, msg.sender, address(this), amount);
        emit Contribution(msg.sender, weth, amount);
    }

    function contributeUsd(uint256 amount) external whenTargetUsdNotReached {
        amountUsdReceived += amount;
        contributionsUsd[msg.sender] += amount;
        SafeTransferLib.safeTransferFrom(usdc, msg.sender, address(this), amount);
        emit Contribution(msg.sender, usdc, amount);
    }
}
