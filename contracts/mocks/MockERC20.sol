// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2024 Fireblocks <support@fireblocks.com>

pragma solidity 0.8.29;

import "@openzeppelin/contracts-v5/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @dev Simple ERC20 mock for testing purposes
 */
contract MockERC20 is ERC20 {
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply,
        address initialOwner
    ) ERC20(name_, symbol_) {
        _mint(initialOwner, initialSupply);
    }

    /**
     * @dev Mint tokens to an address (for testing purposes)
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /**
     * @dev Burn tokens from an address (for testing purposes)
     */
    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}
