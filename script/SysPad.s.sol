// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/SysPad.sol";
import "../src/interfaces/IStakingRewards.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IStakingRewards stakingRewards;

        new SysPad(
            19,
            address(89),
            stakingRewards,
            address(90),
            address(91)
        );

        vm.stopBroadcast();
    }
}
