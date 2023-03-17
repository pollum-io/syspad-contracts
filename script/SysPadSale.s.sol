// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {SysPadSale} from "../src/SysPadSale.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

contract Deploy is Script {

    IERC20 public deployToken;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        new SysPadSale(
            deployToken,
            3 days,
            1678047542,
            1688588342,
            3 days,
            15,
            10000,
            address(87)
        );
        vm.stopBroadcast();
        
    }
}
