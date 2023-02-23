// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/token/ERC20/IERC20.sol";

interface ISysPad {
    function platformFeeAddress() external view returns (address);

    function platformFee() external view returns (uint256);

    function paused() external view returns (bool);

    function owner() external view returns (address);

    function usdc() external view returns (address);

    function usdt() external view returns (address);

    function getTierAt(
        address account,
        uint256 timepoint
    ) external view returns (uint256);
}
