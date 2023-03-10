// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/access/Ownable.sol";
import "@openzeppelin/utils/math/Math.sol";
import "forge-std/console.sol";

/**

@title Staking Rewards Contract
@notice This contract provides a mechanism for users to stake an ERC20 token and receive rewards in another ERC20 token.
The amount of rewards a user receives is proportional to the amount staked and the time staked.
@dev This contract uses a checkpoint mechanism for voting weights that is based on ERC20Votes.sol from OpenZeppelin.
This contract is inspired by the StakingRewards contract from Synthetix.
*/
contract StakingRewards is Ownable {
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardsToken;

    /**
     * @notice The timestamp when the rewards finish.
     */
    uint256 public finishAt;
    /**
     * @notice The minimum of last updated time and reward finish time.
     */
    uint256 public updatedAt;
    /**
     * @notice The reward to be paid out per second.
     */
    uint256 public rewardRate;
    /**
     * @notice The sum of (reward rate * dt * 1e18 / total supply).
     */
    uint256 public rewardPerTokenStored;
    /**
     * @notice The last duration of the rewards.
     */
    uint256 public lastDuration;
    /**
     * @notice A mapping from a user's address to the last recorded rewardPerTokenStored.
     */
    mapping(address => uint256) public userRewardPerTokenPaid;
    /**
     * @notice A mapping from a user's address to their rewards to be claimed.
     */
    mapping(address => uint256) public rewards;
    /**
     * @notice The total amount of staked tokens.
     */
    uint256 public totalSupply;
    /**
     * @notice A mapping from a user's address to their staked amount.
     */
    mapping(address => uint256) public balanceOf;

    /// @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint256 timestamp;
        uint256 balance;
    }

    /// @notice A record of votes checkpoints for each account, by index
    mapping(address => mapping(uint256 => Checkpoint)) public checkpoints;

    /// @notice The number of checkpoints for each account
    mapping(address => uint256) public numCheckpoints;

    constructor(address _stakingToken, address _rewardToken) {
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardToken);
    }

    /**
     * @notice Modifier that updates a user's reward information.
     * @param _account The user's address.
     */
    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = _lastTimeRewardApplicable();

        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }

        _;
    }

    /**
     * @dev Returns the timestamp at which the next reward period starts.
     * If the current block timestamp is before the start of the first reward period, it returns the start of the first reward period.
     */
    function _lastTimeRewardApplicable() internal view returns (uint256) {
        return finishAt <= block.timestamp ? finishAt : block.timestamp;
    }

    /**
     * @dev Calculates and returns the amount of reward tokens that have been accrued since the last reward period.
     */
    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return
            rewardPerTokenStored +
            (rewardRate * (_lastTimeRewardApplicable() - updatedAt) * 1e18) /
            totalSupply;
    }

    /**
     * @dev Stakes a specified amount of tokens and updates the amount of tokens staked by the sender.
     * @param _amount The amount of tokens to stake.
     */
    function stake(uint256 _amount) external updateReward(_msgSender()) {
        require(_amount > 0, "StakingRewards::ZERO_AMOUNT");
        stakingToken.transferFrom(_msgSender(), address(this), _amount);
        balanceOf[_msgSender()] += _amount;
        totalSupply += _amount;
        _writeCheckpoint(_add, _amount);
    }

    /**
     * @dev Withdraws a specified amount of tokens and updates the amount of tokens staked by the sender.
     * @param _amount The amount of tokens to withdraw.
     */
    function withdraw(uint256 _amount) external updateReward(_msgSender()) {
        require(_amount > 0, "StakingRewards::ZERO_AMOUNT");
        balanceOf[_msgSender()] -= _amount;
        totalSupply -= _amount;
        stakingToken.transfer(_msgSender(), _amount);
        _writeCheckpoint(_subtract, _amount);
    }

    /**
     * @notice View function to see the amount of tokens a user can claim
     * @param _account The address of the user to check
     * @return The amount of tokens the user can claim
     */
    function earned(address _account) public view returns (uint256) {
        return
            ((balanceOf[_account] *
                (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18) +
            rewards[_account];
    }

    /**
     * @dev Calculates and transfers the appropriate amount of reward tokens to the sender and updates the reward rate and the timestamp at which the next reward period starts.
     */
    function getReward() external updateReward(_msgSender()) {
        uint256 reward = rewards[_msgSender()];
        if (reward > 0) {
            rewards[_msgSender()] = 0;
            rewardsToken.transfer(_msgSender(), reward);
        }
    }

    /**
     * @notice Notifies the contract of the amount of reward tokens to be distributed for the duration specified.
     * @dev The duration can be defined as any non-negative value.
     * The reward rate for the new duration will be `(amount) / (duration)`.
     * Rewards are always distributed in full periods from the last update time.
     * If the duration is less than the time elapsed since the last reward,
     * the reward for that period is deducted from the total reward.
     * @param _amount The amount of reward tokens to be distributed.
     * @param _duration The duration that the rewards are distributed for.
     */
    function notifyRewardAmount(
        uint256 _amount,
        uint256 _duration
    ) external onlyOwner updateReward(address(0)) {
        if (block.timestamp >= finishAt) {
            rewardRate = _amount / _duration;
        } else {
            uint remainingRewards = (finishAt - block.timestamp) * rewardRate;
            rewardRate = (_amount + remainingRewards) / _duration;
        }
        require(rewardRate > 0, "StakingRewards::ZERO_REWARD_RATE");
        rewardsToken.transferFrom(_msgSender(), address(this), _amount);
        require(
            _amount <= rewardsToken.balanceOf(address(this)),
            "StakingRewards::NOT_ENOUGH_REWARDS"
        );
        lastDuration = _duration;

        finishAt = block.timestamp + _duration;
        updatedAt = block.timestamp;
    }

    /**
     * @notice Returns the current Annual percentage rate in Basis Point.
     * @return _apr The current Annual percentage rate.
     */
    function apr() external view returns (uint256 _apr) {
        require(rewardRate > 0, "StakingRewards::REWARD_RATE_IS_ZERO");
        require(block.timestamp < finishAt, "StakingRewards::REWARD_IS_OVER");
        uint256 rewardPerYear = rewardRate * 365 days;
        uint256 totalStaked = totalSupply;
        _apr = (rewardPerYear * 1e4) / totalStaked;
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param timestamp The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function balanceOfAt(
        address account,
        uint256 timestamp
    ) public view returns (uint256) {
        require(
            timestamp < block.timestamp,
            "StakingRewards::INVALID_TIMESTAMP"
        );

        uint256 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].timestamp <= timestamp) {
            return checkpoints[account][nCheckpoints - 1].balance;
        }

        // Next check implicit zero balance
        if (checkpoints[account][0].timestamp > timestamp) {
            return 0;
        }

        uint256 lower = 0;
        uint256 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint256 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.timestamp == timestamp) {
                return cp.balance;
            } else if (cp.timestamp < timestamp) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].balance;
    }

    function _writeCheckpoint(
        function(uint256, uint256) view returns (uint256) op,
        uint256 delta
    ) internal {
        uint256 nCheckpoints = numCheckpoints[_msgSender()];
        uint256 oldBalance = nCheckpoints > 0
            ? checkpoints[_msgSender()][nCheckpoints - 1].balance
            : 0;
        if (
            nCheckpoints > 0 &&
            checkpoints[_msgSender()][nCheckpoints - 1].timestamp ==
            block.timestamp
        ) {
            checkpoints[_msgSender()][nCheckpoints - 1].balance = op(
                oldBalance,
                delta
            );
        } else {
            checkpoints[_msgSender()][nCheckpoints] = Checkpoint(
                block.timestamp,
                op(oldBalance, delta)
            );
            numCheckpoints[_msgSender()] = nCheckpoints + 1;
        }
    }

    function _add(uint256 a, uint256 b) private pure returns (uint256) {
        return a + b;
    }

    function _subtract(uint256 a, uint256 b) private pure returns (uint256) {
        return a - b;
    }
}
