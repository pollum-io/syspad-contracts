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
    uint256 constant DURATION = 100;

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

    function testCheckpoint() public {
        vm.startPrank(user1);

        for (uint i = 0; i < 6; i++) {
            stakingRewards.stake(100 ether);
            vm.warp(block.timestamp + 100);
            // console.log(
            //     "balanceOfAt",
            //     block.timestamp - 100,
            //     stakingRewards.balanceOfAt(user1, block.timestamp - 100)
            // );
            (uint256 timestamp, uint256 balance) = stakingRewards.checkpoints(
                user1,
                i
            );
            console.log(timestamp, balance);

            stakingRewards.withdraw(100 ether);
            vm.warp(block.timestamp + 100);
        }

        console.log("numCheckpoints", stakingRewards.numCheckpoints(user1));
    }

    function testStakeAndWithdraw() public {
        // vm.startPrank(user1);
        // Stake 100 staking tokens
        // stakingRewards.stake(100 ether);
        // Check that user staked 100 staking tokens
        // assertEq(stakingRewards.balanceOf(user1), 100 ether);
        // assertEq(stakingToken.balanceOf(address(stakingRewards)), 100 ether);
        // Advance time by 1 day
        // vm.warp(1 days);
        // stakingRewards.stake(100 ether);
        // vm.warp(2 days);
        // stakingRewards.stake(100 ether);
        // console.log(
        //     "balanceOfAt",
        //     1,
        //     stakingRewards.balanceOfAt(user1, 1 days + 5)
        // );
        // vm.warp(3 days);
        // stakingRewards.stake(100 ether);
        // console.log(
        //     "balanceOfAt",
        //     2,
        //     stakingRewards.balanceOfAt(user1, 2 days + 5)
        // );
        // vm.warp(4 days);
        // stakingRewards.stake(100 ether);
        // console.log(
        //     "balanceOfAt",
        //     3,
        //     stakingRewards.balanceOfAt(user1, 3 days + 5)
        // );
        // vm.warp(5 days);
        // stakingRewards.stake(100 ether);
        // console.log(
        //     "balanceOfAt",
        //     4,
        //     stakingRewards.balanceOfAt(user1, 4 days + 5)
        // );
        // vm.warp(6 days);
        // stakingRewards.stake(100 ether);
        // Withdraw 50 staking tokens
        // stakingRewards.withdraw(50 ether);
        // // Check that user withdrew 50 staking tokens
        // assertEq(stakingRewards.balanceOf(user1), 50 ether);
        // assertEq(stakingToken.balanceOf(address(stakingRewards)), 50 ether);
        // Advance time by another 1 day
        // vm.warp(7 days);
        // console.log(stakingRewards.checkpoints(user1, 1).balance);
        // console.log(stakingRewards.checkpoints(user1, 1).timestamp);
        // // // Withdraw the rest of the staking tokens
        // stakingRewards.withdraw(50 ether);
        // console.log(stakingRewards.balanceOf(user1));
        // // Check that user withdrew all staking tokens
        // assertEq(stakingRewards.balanceOf(user1), 0);
        // assertEq(stakingToken.balanceOf(address(stakingRewards)), 0);
    }
}
