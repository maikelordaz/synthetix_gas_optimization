# Gas Optimization Audit Report - StakingRewards

## Overview

- **Contract:** StakingRewards.sol
- **Optimized Contract:** StakingRewardsOptimized.sol
- **Audit Objective:** Reduce gas costs
- **Findings Summary:**
  - **Deployment Gas Reduced:** 2,160,624 -> 1,546,600 (↓ 28.4%)
  - **Deployment Size Reduced:** 10,073 -> 7,340 (↓ 27.2%)
  - **Gas Savings on Function Calls:** Significant reductions across multiple functions

## Optimizations & Gas Savings

1. Implement Reverts using Inline Assembly in Yul

In the original contract it was used require statements with string reverts, this was modified to use custom errors and revert using inline assembly. This saves gas costs in deployment and runtime because storing strings is more expensive than storing error codes.

2. Emit Events using inline assembly with opcodes `log1` and  `log2`

3. Use immutable and constant variables, for those that are not modified in the contract.

4. Remove unneded initializations when declaring variables.

5. Remove unnecessary storage access

6. Use ReentrancyGuardTransient instead of ReentrancyGuard

## Gas Comparison

| Function Name              | Original | Optimized | Improvement% |
| -------------------------- | -------- | --------- | -----------  |
| **Deployment Size**        | 10195    | 9062      | 11.11        |
| **Runtime Size**           | 7910     | 7028      | 11.15        |
| `balanceOf`                | 10670    | 10646     | 0.22         |
| `earned`                   | 20067    | 20057     | 0.05         |
| `exit`                     | 132223   | 122736    | 7.17         |
| `getReward`                | 156654   | 153028    | 2.31         |
| `getRewardForDuration`     | 10264    | 10265     | 0            |
| `lastTimeRewardApplicable` | 8049     | 8007      | 0.52         |
| `recoverERC20`             | 44956    | 43253     | 3.79         |
| `rewardPerToken`           | 10070    | 10038     | 0.32         |
| `stake`                    | 140393   | 136670    | 2.65         |
| `totalSupply`              | 7915     | 7888      | 0.34         |
| `withdraw`                 | 158350   | 154619    | 2.36         |
