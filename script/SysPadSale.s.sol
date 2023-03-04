// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/SysPadSale.sol";
import "@openzeppelin/token/ERC20/IERC20.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

    /** Constructor Parameters
     * @param _token address of ERC20 token being sold.
     * @param _duration Number of SysPad Sale duration time.
     * @param _openTime Timestamp of when SysPad Sale starts.
     * @param _releaseTime Timestamp of when SysPadd Slae claim period starts.
     * @param _usdConversionRate Conversion rate for buy token.
     * @param _saleAmount Amount of tokens to sold out.
     * @param _fundingWallet Address where collected funds will be forwarded to.
     */

        // new SysPadSale(
        //     IERC20 _token,
        //     uint256 _duration,
        //     uint256 _openTime,
        //     uint256 _releaseTime,
        //     uint256 _releaseDuration,
        //     uint256 _usdConversionRate,
        //     uint256 _saleAmount,
        //     address _fundingWallet
        // );

        vm.stopBroadcast();
    }
}
