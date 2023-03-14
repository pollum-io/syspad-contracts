// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/extensions/draft-IERC20Permit.sol";

interface ISysPadToken is IERC20, IERC20Permit {}
