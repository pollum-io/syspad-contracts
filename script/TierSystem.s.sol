// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/TierSystem.sol";
// import "./interfaces/IStakingRewards.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // /** Constructor Parameters
        //  * (IStakingRewards _stakingRewards)
        //  */

        // IStakingRewards public stakingRewards;

        // new TierSystem(
        //     stakingRewards
        // );

        vm.stopBroadcast();
    }
}
