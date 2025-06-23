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
pragma solidity 0.8.29;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {LibErrors} from "../../library/Errors/LibErrors.sol";

/**
 * @title RoleBasedOwnable
 * @author Fireblocks
 * @notice This contract is meant to hotwire Ownable-based functions to operate using Role Based Access Control
 * mechanisms instead of single-owner model.
 * @dev A contract that adapts Ownable functions to work with Role Based Access Control. It gives accounts with, for
 * example `CONTRACT_ADMIN_ROLE` the ability to call functions that are restricted to the owner.
 *
 * The Contracts that inherit from this contract:
 *  - The derived contract must implement the `_checkOwner` function to check if the sender has the required role.
 *  - The derived contract can choose which role to use.
 */
abstract contract RoleBasedOwnable is AccessControl, Ownable {
	/// Functions

	/**
	 * @notice The constructor of the RoleBasedOwnable contract.
	 * @dev This constructor sets the contract as the owner and renounces ownership to prevent any address from being
	 * set as the owner.
	 */
	constructor() Ownable(address(this)) {
		// Since we cannot omit Ownable constructor invocation, in order to avoid
		// the owner being set an address, we pass the contract address and now
		// we renounce ownership.
		_transferOwnership(address(0));
	}

	/**
	 * @notice This function revokes an Access Control role from an account
	 * @dev Calling Conditions:
	 *
	 * - Caller must be the role admin of the `role`.
	 * - Non-zero address `account`.
	 *
	 * This function emits a {RoleRevoked} event as part of {AccessControl}.{_revokeRole}.
	 *
	 * @param role The role that will be revoked.
	 * @param account The address from which role is revoked
	 */
	function revokeRole(bytes32 role, address account) public virtual override {
		if (role == DEFAULT_ADMIN_ROLE && account == _msgSender()) {
			revert LibErrors.DefaultAdminError();
		}
		_authorizeRoleManagement();
		AccessControl.revokeRole(role, account);
	}

	/**
	 * @notice  This function renounces an Access Control role from an account, except for the "DEFAULT_ADMIN_ROLE".
	 *
	 * @dev Only the account itself can renounce its own roles, and not any other account.
	 * Calling Conditions:
	 *
	 * - Cannot renounce DEFAULT_ADMIN_ROLE.
	 * - 'account' is the caller of the transaction.
	 */
	function renounceRole(bytes32 role, address account) public virtual override {
		if (role == DEFAULT_ADMIN_ROLE) {
			revert LibErrors.DefaultAdminError();
		}
		_authorizeRoleManagement();
		AccessControl.renounceRole(role, account);
	}

	/**
	 * @notice This function grants an Access Control role to an account
	 * @dev Calling Conditions:
	 *
	 * - Caller must be the role admin of the `role`.
	 * - Non-zero address `account`.
	 *
	 * This function emits a {RoleGranted} event as part of {AccessControl}.{_grantRole}.
	 *
	 * @param role The role that will be granted.
	 * @param account The address to which role is granted
	 */
	function grantRole(bytes32 role, address account) public virtual override {
		_authorizeRoleManagement();
		AccessControl.grantRole(role, account);
	}

	/**
	 * @notice This function is designed to be overridden in inheriting contracts.
	 * @dev Override this function to implement RBAC control or other validations related to role management.
	 */
	function _authorizeRoleManagement() internal virtual;

	/**
	 * @notice This function is designed to be overridden in inheriting contracts.
	 * @dev Override this function to implement RBAC control.
	 * It should throw if the sender does not have a specified role (e.g. CONTRACT_ADMIN_ROLE)
	 */
	function _checkOwner() internal view virtual override {
		revert();
	}
}
