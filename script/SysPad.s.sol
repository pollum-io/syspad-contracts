// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/SysPad.sol";
import "../src/interfaces/IStakingRewards.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        //Constructor Parameters 
        // uint _platformFee, address _feeAddress, IStakingRewards _stakingRewards, 
        // address _usdc, address _usdt
        // new SysPad (
        //     uint256 _platformFee,
        //     address _feeAddress,
        //     IStakingRewards _stakingRewards,
        //     address _usdc,
        //     address _usdt
        // );

        vm.stopBroadcast();
    }
}
