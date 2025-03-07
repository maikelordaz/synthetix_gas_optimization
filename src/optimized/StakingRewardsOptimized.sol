// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// https://docs.synthetix.io/contracts/source/contracts/stakingrewards
contract StakingRewardsOptimized is
    Ownable,
    ReentrancyGuardTransient,
    Pausable
{
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    IERC20 public immutable rewardsToken;
    IERC20 public immutable stakingToken;
    uint256 public periodFinish;
    uint256 public rewardRate;
    uint256 public rewardsDuration = 7 days;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    address public rewardsDistribution;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 public totalSupply;
    mapping(address => uint256) private _balances;

    error StakingRewards__INVALID_ZERO_AMOUNT();
    error StakingRewards__RewardTooHigh();
    error StakingRewards__UnnallowedWitdrwaw();
    error StakingRewards__TimeNotMet();
    error StakingRewards__NotRewardsDistribution();

    uint256 private constant StakingRewards__INVALID_ZERO_AMOUNT_selector =
        0x34c3dc1b;
    uint256 private constant StakingRewards__RewardTooHigh_selector =
        0x6dd9840a;
    uint256 private constant StakingRewards__UnnallowedWitdrwaw_selector =
        0x24e2bbcb;
    uint256 private constant StakingRewards__TimeNotMet_selector = 0xafe8b061;
    uint256 private constant StakingRewards__NotRewardsDistribution_selector =
        0x98e640c1;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _owner,
        address _rewardsDistribution,
        address _rewardsToken,
        address _stakingToken
    ) Ownable(_owner) {
        rewardsToken = IERC20(_rewardsToken);
        stakingToken = IERC20(_stakingToken);
        rewardsDistribution = _rewardsDistribution;
    }

    /* ========== VIEWS ========== */

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        uint256 supply = totalSupply;
        if (supply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            (lastTimeRewardApplicable() -
                (lastUpdateTime * rewardRate * 1e18) /
                supply);
    }

    function earned(address account) public view returns (uint256) {
        return
            _balances[account] *
            rewardPerToken() -
            userRewardPerTokenPaid[account] /
            1e18 +
            rewards[account];
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * rewardsDuration;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(
        uint256 amount
    ) external nonReentrant whenNotPaused updateReward(msg.sender) {
        _requirement(amount > 0, StakingRewards__INVALID_ZERO_AMOUNT_selector);
        totalSupply = totalSupply + amount;
        _balances[msg.sender] = _balances[msg.sender] + amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        assembly {
            let _mptr := mload(0x40)
            mstore(_mptr, amount)
            log2(_mptr, 0x20, StakedSig, caller())
        }
    }

    function withdraw(
        uint256 amount
    ) public nonReentrant updateReward(msg.sender) {
        _requirement(amount > 0, StakingRewards__INVALID_ZERO_AMOUNT_selector);
        totalSupply = totalSupply - amount;
        _balances[msg.sender] = _balances[msg.sender] - amount;
        stakingToken.safeTransfer(msg.sender, amount);

        assembly {
            let _mptr := mload(0x40)
            mstore(_mptr, amount)
            log2(_mptr, 0x20, WithdrawnSig, caller())
        }
    }

    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.safeTransfer(msg.sender, reward);

            assembly {
                let _mptr := mload(0x40)
                mstore(_mptr, reward)
                log2(_mptr, 0x20, RewardPaidSig, caller())
            }
        }
    }

    function exit() external {
        withdraw(_balances[msg.sender]);
        getReward();
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function notifyRewardAmount(
        uint256 reward
    ) external onlyRewardsDistribution updateReward(address(0)) {
        if (block.timestamp >= periodFinish) {
            rewardRate = reward / rewardsDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = reward + leftover / rewardsDuration;
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint balance = rewardsToken.balanceOf(address(this));
        _requirement(
            rewardRate <= balance / rewardsDuration,
            StakingRewards__RewardTooHigh_selector
        );

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;

        assembly {
            let _mptr := mload(0x40)
            mstore(_mptr, reward)
            log1(_mptr, 0x20, RewardAddedSig)
        }
    }

    // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    function recoverERC20(
        address tokenAddress,
        uint256 tokenAmount
    ) external onlyOwner {
        _requirement(
            tokenAddress != address(stakingToken),
            StakingRewards__UnnallowedWitdrwaw_selector
        );
        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);

        assembly {
            let _mptr := mload(0x40)
            mstore(_mptr, tokenAmount)
            log2(_mptr, 0x20, RecoveredSig, caller())
        }
    }

    function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
        _requirement(
            block.timestamp > periodFinish,
            StakingRewards__TimeNotMet_selector
        );
        rewardsDuration = _rewardsDuration;

        assembly {
            let _mptr := mload(0x40)
            mstore(_mptr, _rewardsDuration)
            log1(_mptr, 0x20, RewardsDurationUpdatedSig)
        }
    }

    function setRewardsDistribution(
        address _rewardsDistribution
    ) external onlyOwner {
        rewardsDistribution = _rewardsDistribution;
    }

    /* ========== MODIFIERS ========== */

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    modifier onlyRewardsDistribution() {
        _requirement(
            msg.sender == rewardsDistribution,
            StakingRewards__NotRewardsDistribution_selector
        );
        _;
    }

    function _requirement(bool _condition, uint256 _selector) internal pure {
        assembly {
            if iszero(_condition) {
                let _mptr := mload(0x40)
                mstore(_mptr, _selector)
                revert(_mptr, 0x04)
            }
        }
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsDurationUpdated(uint256 newDuration);
    event Recovered(address token, uint256 amount);

    uint256 private constant RewardAddedSig =
        0xde88a922e0d3b88b24e9623efeb464919c6bf9f66857a65e2bfcf2ce87a9433d;
    uint256 private constant StakedSig =
        0x9e71bc8eea02a63969f509818f2dafb9254532904319f9dbda79b67bd34a5f3d;
    uint256 private constant WithdrawnSig =
        0x7084f5476618d8e60b11ef0d7d3f06914655adb8793e28ff7f018d4c76d505d5;
    uint256 private constant RewardPaidSig =
        0xe2403640ba68fed3a2f88b7557551d1993f84b99bb10ff833f0cf8db0c5e0486;
    uint256 private constant RewardsDurationUpdatedSig =
        0xfb46ca5a5e06d4540d6387b930a7c978bce0db5f449ec6b3f5d07c6e1d44f2d3;
    uint256 private constant RecoveredSig =
        0x8c1256b8896378cd5044f80c202f9772b9d77dc85c8a6eb51967210b09bfaa28;
}
