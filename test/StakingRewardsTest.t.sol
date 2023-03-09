// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/StakingRewards.sol";
import "@openzeppelin/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(
        string memory name,
        string memory symbol
    ) payable ERC20(name, symbol) {}

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }
}

contract StakingRewardsTest is Test {
    uint256 constant DURATION = 100 days;

    MockERC20 public stakingToken;
    StakingRewards public stakingRewards;
    address public owner;

    address user1 = address(1);
    address user2 = address(2);

    function setUp() public {
        owner = address(this);
        stakingToken = new MockERC20("Staking Token", "STK");

        stakingRewards = new StakingRewards(
            address(stakingToken), // reward token
            address(stakingToken) // staking token
        );

        // Mint some staking tokens for the user
        stakingToken.mint(user1, 1000 ether);
        vm.prank(user1);
        stakingToken.approve(address(stakingRewards), 1000 ether);
    }

    // Essentially just check if the checkpoints are working correctly.
    function testStakeWithdrawAndCheckpoints() public {
        vm.startPrank(user1);
        // Stake 100 staking tokens
        stakingRewards.stake(100 ether);
        // Check that user staked 100 staking tokens
        assertEq(stakingRewards.balanceOf(user1), 100 ether);
        assertEq(stakingToken.balanceOf(address(stakingRewards)), 100 ether);
        assertEq(stakingRewards.totalSupply(), 100 ether);
        // Advance time by 1 day
        vm.warp(1 days);

        // Withdraw 50 staking tokens
        stakingRewards.withdraw(50 ether);
        // Check that user withdrew 50 staking tokens
        assertEq(stakingRewards.balanceOf(user1), 50 ether);
        assertEq(stakingToken.balanceOf(address(stakingRewards)), 50 ether);
        assertEq(stakingRewards.totalSupply(), 50 ether);

        // Advance time by another 1 day
        vm.warp(2 days);

        // // Withdraw the rest of the staking tokens
        stakingRewards.withdraw(50 ether);

        // Check that user withdrew all staking tokens
        assertEq(stakingRewards.balanceOf(user1), 0);
        assertEq(stakingToken.balanceOf(address(stakingRewards)), 0);
        assertEq(stakingRewards.totalSupply(), 0);

        vm.warp(3 days);

        // check the checkpoints
        assertEq(stakingRewards.balanceOfAt(user1, 0), 0);
        assertEq(stakingRewards.balanceOfAt(user1, 1 days - 1), 100 ether);
        assertEq(stakingRewards.balanceOfAt(user1, 2 days - 1), 50 ether);
        assertEq(stakingRewards.balanceOfAt(user1, 3 days - 1), 0);
    }

    function testRewardsAndCheckpoints() public {
        // Set up the test
        uint256 stakingTokens = 1000 ether;
        uint256 duration = 100 days;
        uint256 rewardAmount = 1000 ether;

        // Mint some staking tokens for the user
        stakingToken.mint(owner, rewardAmount);

        stakingToken.approve(address(stakingRewards), rewardAmount);

        // Notify the contract of the reward amount and duration
        stakingRewards.notifyRewardAmount(rewardAmount, duration);

        // check the reward rate
        assertEq(stakingRewards.rewardRate(), rewardAmount / duration);

        // check finish at
        assertEq(stakingRewards.finishAt(), block.timestamp + duration);

        // check transfer of reward tokens
        assertEq(stakingToken.balanceOf(address(stakingRewards)), rewardAmount);

        vm.startPrank(user1);
        stakingToken.approve(address(stakingRewards), stakingTokens);

        // // Stake tokens
        stakingRewards.stake(stakingTokens);

        // check totalSupply
        assertEq(stakingRewards.totalSupply(), stakingTokens);

        // check balanceOf
        assertEq(stakingRewards.balanceOf(user1), stakingTokens);

        // // Advance time by 50 days
        vm.warp(50 days);

        // Calculate the expected reward for the user
        uint256 expectedReward = (stakingRewards.rewardPerToken() *
            stakingTokens) / 1e18;

        // Get the actual reward from the contract
        uint256 actualReward = stakingRewards.earned(user1);

        // Compare the expected and actual rewards
        assertEq(expectedReward, actualReward);

        stakingRewards.getReward();
        assertEq(stakingToken.balanceOf(user1), actualReward);
        assertEq(
            stakingRewards.userRewardPerTokenPaid(user1),
            stakingRewards.rewardPerToken()
        );
        assertEq(stakingRewards.rewards(user1), 0);
        assertEq(stakingRewards.totalSupply(), stakingTokens);
        assertEq(stakingRewards.numCheckpoints(user1), 1);
        stakingRewards.withdraw(stakingTokens);
        assertEq(stakingRewards.balanceOf(user1), 0);
        assertEq(stakingRewards.numCheckpoints(user1), 2);
    }
}
