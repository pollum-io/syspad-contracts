// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/token/ERC20/IERC20.sol";

interface IStakingRewards {
    function balanceOfAt(
        address account,
        uint256 timepoint
    ) external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);
}
