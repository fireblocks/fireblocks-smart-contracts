// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.29;

/**
 * @title MockInvalidToken
 * @notice Mock contract for testing invalid ERC20 implementations
 */
contract MockInvalidToken {
    string public name = "Invalid Token";
    string public symbol = "INVALID";

    // Empty contract missing most ERC20 functions to ensure it's not a valid ERC20
}

/**
 * @title MockZeroDecimalsToken
 * @notice Mock contract that implements decimals() but returns 0
 */
contract MockZeroDecimalsToken {
    string public name = "Zero Decimals Token";
    string public symbol = "ZERO";

    function decimals() external pure returns (uint8) {
        return 0;
    }
}
