// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/token/ERC20/extensions/draft-ERC20Permit.sol";

/**
 * @title SysPad
 * @dev {ERC20} token, including:
 *
 *  - ability for holders to sign permits and save gas via one less tx on external token transfers through {ERC20Permit}
 *
 * The account that deploys the contract will specify main parameters via constructor,
 * paying close attention to "admin" address who will receive 100% of initial supply and
 * should then distribute tokens according to tokenomics & planning.
 * inherited from {ERC20} and {ERC20Permit}
 */
contract SysPad is ERC20Permit {
    /**
     * @dev Mints `initialSupply` amount of token and transfers them to `admin`.
     * Also sets domain separator under same token name for EIP712 in ERC20Permit.
     *
     * See {ERC20-constructor} and {ERC20Permit-constructor}.
     * @param initialSupply total supply of the token
     * @param admin address of the admin
     */
    constructor(
        uint256 initialSupply,
        address admin
    ) ERC20("SysPad", "sPad") ERC20Permit("SysPad") {
        _mint(admin, initialSupply);
    }
}
