// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {StakingRewards} from "../src/original/StakingRewards.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract GasTestOriginal is Test {
    StakingRewards public stakingRewards;
    MockERC20 public rewardsToken;
    MockERC20 public stakingToken;
    MockERC20 public recoverToken;

    address owner = makeAddr("Owner");
    address rewardsDistribution = makeAddr("RewardsDistribution");
    address Alice = makeAddr("Alice");
    address Bob = makeAddr("Bob");

    function setUp() public {
        rewardsToken = new MockERC20("Rewards", "RWD");
        stakingToken = new MockERC20("Staking", "STK");
        recoverToken = new MockERC20("Recover", "RTR");
        stakingRewards = new StakingRewards(
            owner,
            rewardsDistribution,
            address(rewardsToken),
            address(stakingToken)
        );

        stakingToken.mint(Alice, 1000e18);
        stakingToken.mint(Bob, 1000e18);
        recoverToken.mint(owner, 1000e18);
    }

    function testGetRewardForDuration() public view {
        uint256 duration = stakingRewards.getRewardForDuration();
        console.log("duration", duration);
    }

    function testLastTimeRewardApplicable() public view {
        uint256 lastTime = stakingRewards.lastTimeRewardApplicable();
        assertEq(lastTime, 0);
    }

    function testStake() public {
        _stakeAlice(888e18);
    }

    function testWithdraw() public {
        uint256 amount = 888e18;
        _stakeAlice(amount);

        uint256 stakingBalBefore = stakingRewards.balanceOf(Alice);
        uint256 tokenBalBefore = stakingToken.balanceOf(Alice);

        uint256 withdrawAmount = amount / 2;

        vm.startPrank(Alice);
        stakingRewards.withdraw(withdrawAmount);
        vm.stopPrank();

        uint256 stakingBalAfter = stakingRewards.balanceOf(Alice);
        uint256 tokenBalAfter = stakingToken.balanceOf(Alice);

        assertEq(stakingBalAfter, stakingBalBefore - withdrawAmount);
        assertEq(tokenBalAfter, tokenBalBefore + withdrawAmount);
    }

    function testGetReward() public {
        _stakeAlice(888e18);

        vm.warp(block.timestamp + 5 days);
        stakingRewards.getReward();
    }

    function testExit() public {
        _stakeAlice(888e18);

        uint256 stakingBalBefore = stakingRewards.balanceOf(Alice);
        uint256 tokenBalBefore = stakingToken.balanceOf(Alice);

        vm.startPrank(Alice);
        vm.warp(block.timestamp + 5 days);
        stakingRewards.exit();
        vm.stopPrank();

        uint256 stakingBalAfter = stakingRewards.balanceOf(Alice);
        uint256 tokenBalAfter = stakingToken.balanceOf(Alice);

        assertEq(stakingBalAfter, 0);
        assertEq(tokenBalAfter, tokenBalBefore + stakingBalBefore);
    }

    function testRecoverERC20() public {
        vm.startPrank(owner);
        recoverToken.transfer(address(stakingRewards), 500e18);
        assertEq(recoverToken.balanceOf(address(stakingRewards)), 500e18);

        stakingRewards.recoverERC20(address(recoverToken), 500e18);
        vm.stopPrank();

        assertEq(recoverToken.balanceOf(owner), 1000e18);
    }

    function _stakeAlice(uint256 amount) internal {
        vm.startPrank(Alice);
        stakingToken.approve(address(stakingRewards), type(uint256).max);
        stakingRewards.stake(amount);
        vm.stopPrank();

        uint256 totalSupply = stakingRewards.totalSupply();
        assertEq(totalSupply, amount);

        uint256 balanceOfAlice = stakingRewards.balanceOf(Alice);
        assertEq(balanceOfAlice, amount);
    }
}
