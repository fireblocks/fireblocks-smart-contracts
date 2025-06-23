// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025 Fireblocks <support@fireblocks.com>
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

import {AccessControl} from "@openzeppelin/contracts-v5/access/AccessControl.sol";

/**
 * @title BoundedRoleMembership
 * @author Fireblocks
 * @notice Abstract contract that extends AccessControl to limit the number of accounts per role
 * @dev This contract tracks the number of members for each role and enforces maximum limits.
 *      Inheriting contracts must implement `_maxRoleMembers` to define limits per role.
 *      A limit of 0 means unlimited members are allowed for that role.
 *
 * @custom:security-contact support@fireblocks.com
 */
abstract contract BoundedRoleMembership is AccessControl {
    /// State

    /**
     * @notice Tracks the current number of members for each role
     * @dev Mapping from role identifier to member count
     */
    mapping(bytes32 role => uint256 memberCount) internal _roleMemberCounts;

    /// Errors

    /**
     * @notice Thrown when attempting to grant a role that has reached its member limit
     * @param role The role that has reached its limit
     * @param limit The maximum number of members allowed for the role
     */
    error RoleLimitReached(bytes32 role, uint256 limit);

    /// Internal Functions

    /**
     * @notice Grants a role to an account with limit enforcement
     * @dev Overrides AccessControl's {_grantRole} to check role limits before granting.
     *      If the role has a limit (non-zero return from _maxRoleMembers), it ensures
     *      the current member count is below the limit before granting.
     *
     * @param role The role to grant
     * @param account The account to grant the role to
     * @return True if the role was granted, false if the account already had the role
     */
    function _grantRole(bytes32 role, address account) internal virtual override returns (bool) {
        if (super._grantRole(role, account)) {
            uint256 limit = _maxRoleMembers(role);
            if (limit > 0) {
                require(_roleMemberCounts[role] < limit, RoleLimitReached(role, limit));
            }
            unchecked {
                _roleMemberCounts[role]++;
            }
            return true;
        }
        return false;
    }

    /**
     * @notice Revokes a role from an account and updates the member count
     * @dev Overrides AccessControl's _revokeRole to maintain accurate member counts.
     *      The count is decremented only if the role was actually revoked.
     *
     * @param role The role to revoke
     * @param account The account to revoke the role from
     * @return True if the role was revoked, false if the account didn't have the role
     */
    function _revokeRole(bytes32 role, address account) internal virtual override returns (bool) {
        if (super._revokeRole(role, account)) {
            // Decrement count - safe to use unchecked as count cannot go below 0
            // (we only decrement if the account had the role)
            unchecked {
                _roleMemberCounts[role]--;
            }
            return true;
        }
        return false;
    }

    /**
     * @notice Returns the maximum number of members allowed for a given role
     * @dev Must be implemented by inheriting contracts to define role-specific limits.
     *      Returning 0 means the role has no member limit (unlimited members allowed).
     *
     * @param role The role to check the limit for
     * @return The maximum number of members allowed (0 for unlimited)
     */
    function _maxRoleMembers(bytes32 role) internal pure virtual returns (uint256);

    /// Public View Functions

    /**
     * @notice Returns the current number of members for a given role
     * @dev This count is maintained automatically as roles are granted and revoked
     *
     * @param role The role to check the member count for
     * @return The current number of accounts that have the specified role
     */
    function getRoleMemberCount(bytes32 role) public view virtual returns (uint256) {
        return _roleMemberCounts[role];
    }
}
