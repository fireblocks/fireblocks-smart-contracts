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

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title PauseCapable
 * @author Fireblocks
 * @notice This abstract contract provides internal contract logic for pausing and unpausing the contract.
 * @dev This contract is meant to be inherited by other contracts that require pausing functionality. It uses
 * OpenZeppelin's Pausable contract to implement the pause and unpause functionality. The inheriting contract must
 * implement the `_authorizePause` function to provide role-based access control for pausing and unpausing the
 * contract.
 */
abstract contract PauseCapable is Pausable {
	/// Functions

	/**
	 * @dev Initializes the contract in an unpaused state.
	 * Inherits from OpenZeppelin's Pausable contract.
	 */
	constructor() Pausable() {}

	/**
	 * @notice This is a function used to pause the contract.
	 *
	 * @dev Calling Conditions:
	 *
	 * - Contract is not paused. (checked internally by {Pausable._pause})
	 *
	 * This function emits a {Paused} event as part of {Pausable._pause}.
	 */
	function pause() external virtual {
		_authorizePause();
		_pause();
	}

	/**
	 * @notice This is a function used to unpause the contract.
	 *
	 * @dev Calling Conditions:
	 *
	 * - Contract is paused. (checked internally by {Pausable._unpause})
	 *
	 * This function emits an {Unpaused} event as part of {Pausable._unpause}.
	 */
	function unpause() external virtual {
		_authorizePause();
		_unpause();
	}

	/**
	 * @notice This function is designed to be overridden in inheriting contracts.
	 * @dev Override this function to implement RBAC control.
	 */
	function _authorizePause() internal virtual;
}
