// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/StakingRewards.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // address _stakingToken, address _rewardToken
        
        new StakingRewards(
            address(0),
            address(1)
        );

        vm.stopBroadcast();
    }
}
