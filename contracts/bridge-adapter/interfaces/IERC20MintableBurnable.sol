// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2024 Fireblocks <support@fireblocks.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
pragma solidity 0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IERC20MintableBurnable
 * @author Fireblocks
 * @notice Interface for ERC20 tokens with mint and burn capabilities.
 */
interface IERC20MintableBurnable is IERC20 {
	/**
	 * @notice Mints new tokens to the specified address.
	 * @param to The address to receive the newly minted tokens.
	 * @param amount The amount of tokens to mint.
	 */
	function mint(address to, uint256 amount) external;

	/**
	 * @notice Burns tokens from the specified address.
	 * @param amount The amount of tokens to burn.
	 */
	function burn(uint256 amount) external;
}
