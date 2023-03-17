// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/SysPad.sol";
import "../src/interfaces/IStakingRewards.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        uint8 platformFee = 10;
        address feeAddress = address(89);
        IStakingRewards stakingRewards;
        address usdc = address(90);
        address usdt = address(91);

        new SysPad(
            platformFee,
            feeAddress,
            stakingRewards,
            usdc,
            usdt
        );

        vm.stopBroadcast();
    }
}
