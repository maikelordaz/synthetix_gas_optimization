// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {StakingRewardsOptimized} from "../src/optimized/StakingRewardsOptimized.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract GasTestOptimized is Test {
    StakingRewardsOptimized public stakingRewards;
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
        stakingRewards = new StakingRewardsOptimized(
            owner,
            rewardsDistribution,
            address(rewardsToken),
            address(stakingToken)
        );

        stakingToken.mint(Alice, 1000e18);
        recoverToken.mint(owner, 1000e18);
    }

    function test_optimizedTotalSupply() public view {
        stakingRewards.totalSupply();
    }

    function test_optimizedBalanceOf() public view {
        stakingRewards.balanceOf(Alice);
    }

    function test_optimizedLastTimeRewardApplicable() public view {
        stakingRewards.lastTimeRewardApplicable();
    }

    function test_optimizedRewardPerToken() public view {
        stakingRewards.rewardPerToken();
    }

    function test_optimizedEarned() public view {
        stakingRewards.earned(Alice);
    }

    function test_optimizedGetRewardForDuration() public view {
        stakingRewards.getRewardForDuration();
    }

    function test_optimizedStake() public {
        _stake(100e18);
    }

    function test_optimizedWithdraw() public {
        _stake(100e18);

        uint256 withdrawAmount = 100e18 / 2;

        vm.startPrank(Alice);
        stakingRewards.withdraw(withdrawAmount);
        vm.stopPrank();
    }

    function test_optimizedGetReward() public {
        _stake(100e18);

        vm.warp(block.timestamp + 5 days);
        stakingRewards.getReward();
    }

    function test_optimizedExit() public {
        _stake(100e18);

        vm.warp(block.timestamp + 5 days);

        vm.prank(Alice);
        stakingRewards.exit();
    }

    function test_optimizedRecoverERC20() public {
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
