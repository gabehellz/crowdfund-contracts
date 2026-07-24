// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.36;

import {Test} from "forge-std/Test.sol";
import {Crowdfund} from "../src/Crowdfund.sol";
import {WETH} from "solady/src/tokens/WETH.sol";
import {MockERC20} from "solady/test/utils/mocks/MockERC20.sol";

contract CrowdfundTest is Test {
    uint256 public constant TARGET_ETH_AMOUNT = 10 ether;
    uint256 public constant TARGET_USD_AMOUNT = 5000 * 10e6;

    address public immutable alice = makeAddr("alice");
    address public immutable bob = makeAddr("bob");
    address public crowdFundAddress;

    WETH public weth;
    MockERC20 public usdc;
    Crowdfund public crowdFund;

    event Approval(address indexed caller, address indexed spender, uint256 amount);

    function setUp() public {
        weth = new WETH();
        usdc = new MockERC20("Mock USDC ERC 20", "USDC", uint8(6));
        crowdFund = new Crowdfund(alice, address(weth), address(usdc), TARGET_ETH_AMOUNT, TARGET_USD_AMOUNT);
        crowdFundAddress = address(crowdFund);
    }

    function _contribute(address contributor, uint256 amount, bool direct) internal {
        hoax(contributor, amount);

        uint256 balanceBefore = crowdFundAddress.balance;
        uint256 contributorBalanceBefore = contributor.balance;

        vm.expectEmit(true, true, false, false);
        emit Crowdfund.Contribution(contributor, address(0), amount);

        if (direct) {
            (bool success,) = crowdFundAddress.call{value: amount}("");
            assert(success);
        } else {
            crowdFund.contribute{value: amount}();
        }

        uint256 balanceAfter = crowdFundAddress.balance;
        uint256 contributorBalanceAfter = contributor.balance;

        assertEq(balanceAfter - balanceBefore, amount);
        assertEq(contributorBalanceBefore - contributorBalanceAfter, amount);
    }

    function _contributeFail(address contributor, uint256 amount, bool direct) internal {
        hoax(contributor, amount);

        uint256 balanceBefore = crowdFundAddress.balance;
        uint256 contributorBalanceBefore = contributor.balance;

        vm.expectRevert(Crowdfund.TargetEthAmountReached.selector);

        if (direct) {
            (bool success,) = crowdFundAddress.call{value: amount}("");
            assert(success);
        } else {
            crowdFund.contribute{value: amount}();
        }

        uint256 balanceAfter = crowdFundAddress.balance;
        uint256 contributorBalanceAfter = contributor.balance;

        assertEq(balanceAfter, balanceBefore);
        assertEq(contributorBalanceAfter, contributorBalanceBefore);
    }

    function _contributeWithWeth(address contributor, uint256 amount) internal {
        vm.deal(contributor, amount);
        vm.startPrank(contributor);

        uint256 contributorBalanceBefore = contributor.balance;
        weth.deposit{value: amount}();

        uint256 wethBalanceBefore = weth.balanceOf(crowdFundAddress);
        uint256 contributorWethBalanceBefore = weth.balanceOf(contributor);
        assertEq(contributorBalanceBefore, contributorWethBalanceBefore);

        uint256 allowanceBefore = weth.allowance(contributor, crowdFundAddress);

        vm.expectEmit(true, true, true, false);
        emit Approval(contributor, crowdFundAddress, amount);
        bool success = weth.approve(crowdFundAddress, amount);
        assert(success);

        uint256 allowanceAfter = weth.allowance(contributor, crowdFundAddress);
        assertEq(allowanceAfter - allowanceBefore, amount);

        vm.expectEmit(true, true, false, false);
        emit Crowdfund.Contribution(contributor, address(weth), amount);
        crowdFund.contributeWrapped(amount);
        vm.stopPrank();

        uint256 wethBalanceAfter = weth.balanceOf(crowdFundAddress);
        assertEq(wethBalanceAfter - wethBalanceBefore, amount);

        uint256 contributorWethBalanceAfter = weth.balanceOf(contributor);
        assertEq(contributorWethBalanceBefore - contributorWethBalanceAfter, amount);
    }

    function _contributeWithWethNoAllowance(address contributor, uint256 amount) internal {
        vm.deal(contributor, amount);
        vm.startPrank(contributor);

        uint256 contributorBalanceBefore = contributor.balance;
        weth.deposit{value: amount}();

        uint256 wethBalanceBefore = weth.balanceOf(crowdFundAddress);
        uint256 contributorWethBalanceBefore = weth.balanceOf(contributor);
        assertEq(contributorBalanceBefore, contributorWethBalanceBefore);

        vm.expectPartialRevert(0x7939f424);
        crowdFund.contributeWrapped(amount);
        vm.stopPrank();

        uint256 wethBalanceAfter = weth.balanceOf(crowdFundAddress);
        assertEq(wethBalanceAfter, wethBalanceBefore);

        uint256 contributorWethBalanceAfter = weth.balanceOf(contributor);
        assertEq(contributorWethBalanceBefore, contributorWethBalanceAfter);
    }

    function _contributeWithWethFail(address contributor, uint256 amount) internal {
        vm.deal(contributor, amount);
        vm.startPrank(contributor);

        uint256 contributorBalanceBefore = contributor.balance;
        weth.deposit{value: amount}();

        uint256 wethBalanceBefore = weth.balanceOf(crowdFundAddress);
        uint256 contributorWethBalanceBefore = weth.balanceOf(contributor);
        assertEq(contributorBalanceBefore, contributorWethBalanceBefore);

        uint256 allowanceBefore = weth.allowance(contributor, crowdFundAddress);

        vm.expectEmit(true, true, true, false);
        emit Approval(contributor, crowdFundAddress, amount);
        bool success = weth.approve(crowdFundAddress, amount);
        assert(success);

        uint256 allowanceAfter = weth.allowance(contributor, crowdFundAddress);
        assertEq(allowanceAfter - allowanceBefore, amount);

        vm.expectRevert(Crowdfund.TargetEthAmountReached.selector);
        crowdFund.contributeWrapped(amount);
        vm.stopPrank();

        uint256 wethBalanceAfter = weth.balanceOf(crowdFundAddress);
        assertEq(wethBalanceAfter, wethBalanceBefore);

        uint256 contributorWethBalanceAfter = weth.balanceOf(contributor);
        assertEq(contributorWethBalanceBefore, contributorWethBalanceAfter);
    }

    function _contributeWithUsdc(address contributor, uint256 amount) internal {
        usdc.mint(contributor, amount);
        vm.startPrank(contributor);

        uint256 usdcBalanceBefore = usdc.balanceOf(crowdFundAddress);
        uint256 contributorUsdcBalanceBefore = usdc.balanceOf(contributor);
        uint256 allowanceBefore = usdc.allowance(contributor, crowdFundAddress);

        vm.expectEmit(true, true, true, false);
        emit Approval(contributor, crowdFundAddress, amount);
        bool success = usdc.approve(crowdFundAddress, amount);
        assert(success);

        uint256 allowanceAfter = usdc.allowance(contributor, crowdFundAddress);
        assertEq(allowanceAfter - allowanceBefore, amount);

        vm.expectEmit(true, true, false, false);
        emit Crowdfund.Contribution(contributor, address(usdc), amount);
        crowdFund.contributeUsd(amount);
        vm.stopPrank();

        uint256 usdcBalanceAfter = usdc.balanceOf(crowdFundAddress);
        assertEq(usdcBalanceAfter - usdcBalanceBefore, amount);

        uint256 contributorUsdcBalanceAfter = usdc.balanceOf(contributor);
        assertEq(contributorUsdcBalanceBefore - contributorUsdcBalanceAfter, amount);
    }

    function _contributeWithUsdcNoAllowance(address contributor, uint256 amount) internal {
        usdc.mint(contributor, amount);
        vm.startPrank(contributor);

        uint256 usdcBalanceBefore = usdc.balanceOf(crowdFundAddress);
        uint256 contributorUsdcBalanceBefore = usdc.balanceOf(contributor);

        vm.expectPartialRevert(0x7939f424);
        crowdFund.contributeUsd(amount);
        vm.stopPrank();

        uint256 usdcBalanceAfter = usdc.balanceOf(crowdFundAddress);
        assertEq(usdcBalanceAfter, usdcBalanceBefore);

        uint256 contributorUsdcBalanceAfter = usdc.balanceOf(contributor);
        assertEq(contributorUsdcBalanceBefore, contributorUsdcBalanceAfter);
    }

    function _contributeWithUsdcFail(address contributor, uint256 amount) internal {
        usdc.mint(contributor, amount);
        vm.startPrank(contributor);

        uint256 usdcBalanceBefore = usdc.balanceOf(crowdFundAddress);
        uint256 contributorUsdcBalanceBefore = usdc.balanceOf(contributor);
        uint256 allowanceBefore = usdc.allowance(contributor, crowdFundAddress);

        vm.expectEmit(true, true, true, false);
        emit Approval(contributor, crowdFundAddress, amount);
        bool success = usdc.approve(crowdFundAddress, amount);
        assert(success);

        uint256 allowanceAfter = usdc.allowance(contributor, crowdFundAddress);
        assertEq(allowanceAfter - allowanceBefore, amount);

        vm.expectRevert(Crowdfund.TargetUsdAmountReached.selector);
        crowdFund.contributeUsd(amount);
        vm.stopPrank();

        uint256 usdcBalanceAfter = usdc.balanceOf(crowdFundAddress);
        assertEq(usdcBalanceAfter, usdcBalanceBefore);

        uint256 contributorUsdcBalanceAfter = usdc.balanceOf(contributor);
        assertEq(contributorUsdcBalanceBefore, contributorUsdcBalanceAfter);
    }

    function testFuzz_contribute(uint256 amount) public {
        amount = bound(amount, 1, type(uint256).max);
        _contribute(bob, amount, false);
    }

    function test_contribute_withTargetAmountEthAndOneEth() public {
        _contribute(bob, TARGET_ETH_AMOUNT, false);
        _contributeFail(bob, 1 ether, false);
    }

    function testFuzz_directContribute(uint256 amount) public {
        amount = bound(amount, 1, type(uint256).max);
        _contribute(bob, amount, true);
    }

    function test_directContribute_withTargetAmountEthAndOneEth() public {
        _contribute(bob, TARGET_ETH_AMOUNT, true);
        _contributeFail(bob, 1 ether, true);
    }

    function testFuzz_contributeWrapped(uint256 amount) public {
        amount = bound(amount, 1, type(uint256).max);
        _contributeWithWeth(bob, amount);
    }

    function testFuzz_contributeWrapped_NoAllowance(uint256 amount) public {
        amount = bound(amount, 1, type(uint256).max);
        _contributeWithWethNoAllowance(bob, amount);
    }

    function test_contributeWrapped_withTargetAmountWethAndOneWeth() public {
        _contributeWithWeth(bob, TARGET_ETH_AMOUNT);
        _contributeWithWethFail(bob, 1 ether);
    }

    function testFuzz_contributeUsd(uint256 amount) public {
        amount = bound(amount, 1e6, type(uint256).max);
        _contributeWithUsdc(bob, amount);
    }

    function testFuzz_contributeUsd_NoAllowance(uint256 amount) public {
        amount = bound(amount, 1e6, type(uint256).max);
        _contributeWithUsdcNoAllowance(bob, amount);
    }

    function test_contributeUsd_withTargetAmountUsdAndOneUsd() public {
        _contributeWithUsdc(bob, TARGET_USD_AMOUNT);
        _contributeWithUsdcFail(bob, 1e6);
    }
}
