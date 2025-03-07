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
        recoverToken.mint(owner, 1000e18);
    }

    function testTotalSupply() public view {
        stakingRewards.totalSupply();
    }

    function testBalanceOf() public view {
        stakingRewards.balanceOf(Alice);
    }

    function testLastTimeRewardApplicable() public view {
        stakingRewards.lastTimeRewardApplicable();
    }

    function testRewardPerToken() public view {
        stakingRewards.rewardPerToken();
    }

    function testEarned() public view {
        stakingRewards.earned(Alice);
    }

    function testGetRewardForDuration() public view {
        stakingRewards.getRewardForDuration();
    }

    function testStake() public {
        _stake(100e18);
    }

    function testWithdraw() public {
        _stake(100e18);

        uint256 withdrawAmount = 100e18 / 2;

        vm.startPrank(Alice);
        stakingRewards.withdraw(withdrawAmount);
        vm.stopPrank();
    }

    function testGetReward() public {
        _stake(100e18);

        vm.warp(block.timestamp + 5 days);
        stakingRewards.getReward();
    }

    function testExit() public {
        _stake(100e18);

        vm.warp(block.timestamp + 5 days);

        vm.prank(Alice);
        stakingRewards.exit();
    }

    function testRecoverERC20() public {
        vm.startPrank(owner);
        recoverToken.transfer(address(stakingRewards), 500e18);
        assertEq(recoverToken.balanceOf(address(stakingRewards)), 500e18);

        stakingRewards.recoverERC20(address(recoverToken), 500e18);
        vm.stopPrank();
    }

    function _stake(uint256 amount) internal {
        vm.startPrank(Alice);
        stakingToken.approve(address(stakingRewards), type(uint256).max);
        stakingRewards.stake(amount);
        vm.stopPrank();
    }
}
