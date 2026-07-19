// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.36;

import {Test} from "forge-std/Test.sol";
import {Crowdfund} from "../src/Crowdfund.sol";

contract CrowdfundTest is Test {
    uint256 public constant TARGET_AMOUNT = 10 ether;

    address public immutable alice = makeAddr("alice");
    address public immutable bob = makeAddr("bob");

    Crowdfund public crowdFund;

    function setUp() public {
        crowdFund = new Crowdfund(alice, TARGET_AMOUNT);
    }

    function _contribute(address contributor, uint256 amount) internal {
        hoax(contributor, amount);

        uint256 balanceBefore = address(crowdFund).balance;
        uint256 bobBalanceBefore = address(bob).balance;

        vm.expectEmit(true, true, false, false);
        emit Crowdfund.Contribution(bob, amount);
        crowdFund.contribute{value: amount}();

        uint256 balanceAfter = address(crowdFund).balance;
        uint256 bobBalanceAfter = address(bob).balance;

        assertEq(balanceAfter - balanceBefore, amount);
        assertEq(bobBalanceBefore - bobBalanceAfter, amount);
    }

    function _contributeFail(address contributor, uint256 amount) internal {
        hoax(contributor, amount);

        uint256 balanceBefore = address(crowdFund).balance;
        uint256 bobBalanceBefore = address(bob).balance;

        vm.expectRevert(Crowdfund.TargetAmountReached.selector);
        crowdFund.contribute{value: amount}();

        uint256 balanceAfter = address(crowdFund).balance;
        uint256 bobBalanceAfter = address(bob).balance;

        assertEq(balanceAfter, balanceBefore);
        assertEq(bobBalanceAfter, bobBalanceBefore);
    }

    function _directContribute(address contributor, uint256 amount) internal {
        hoax(contributor, amount);

        uint256 balanceBefore = address(crowdFund).balance;
        uint256 bobBalanceBefore = address(bob).balance;

        vm.expectEmit(true, true, false, false);
        emit Crowdfund.Contribution(bob, amount);
        (bool success,) = address(crowdFund).call{value: amount}("");
        assert(success);

        uint256 balanceAfter = address(crowdFund).balance;
        uint256 bobBalanceAfter = address(bob).balance;

        assertEq(balanceAfter - balanceBefore, amount);
        assertEq(bobBalanceBefore - bobBalanceAfter, amount);
    }

    function _directContributeFail(address contributor, uint256 amount) internal {
        hoax(contributor, amount);

        uint256 balanceBefore = address(crowdFund).balance;
        uint256 bobBalanceBefore = address(bob).balance;

        vm.expectRevert(Crowdfund.TargetAmountReached.selector);
        (bool success,) = address(crowdFund).call{value: amount}("");
        assert(success);

        uint256 balanceAfter = address(crowdFund).balance;
        uint256 bobBalanceAfter = address(bob).balance;

        assertEq(balanceAfter, balanceBefore);
        assertEq(bobBalanceAfter, bobBalanceBefore);
    }

    function testFuzz_contribute_withOneEth(uint256 amount) public {
        _contribute(bob, amount);
    }

    function test_contribute_withTargetAmountEthAndOneEth() public {
        _contribute(bob, TARGET_AMOUNT);
        _contributeFail(bob, 1 ether);
    }

    function testFuzz_directContribute_withOneEth(uint256 amount) public {
        _directContribute(bob, amount);
    }

    function test_directContribute_withTargetAmountEthAndOneEth() public {
        _directContribute(bob, TARGET_AMOUNT);
        _directContributeFail(bob, 1 ether);
    }
}
