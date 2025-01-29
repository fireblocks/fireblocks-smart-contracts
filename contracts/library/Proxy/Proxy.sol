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

import { ERC1967Proxy } from "@openzeppelin/contracts-v5/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title Proxy
 * @author Fireblocks
 * @notice A proxy contract that delegates all calls to an implementation (logic) contract.
 * 
 * @dev Inherits from the ERC1967Proxy contract, which follows the EIP-1967 standard for upgradeable contracts.
 * This contract sets up the initial implementation and optionally executes an initialization call.
 * 
 * @custom:security-contact support@fireblocks.com
 */
contract Proxy is ERC1967Proxy {
	/// Functions

	/**
	 * @notice This function acts as the constructor of the contract.
	 * @param _logic The address of the logic contract.
	 * @param _data The data to be used in the delegate call.
	 */
	constructor(address _logic, bytes memory _data) ERC1967Proxy(_logic, _data) payable {}
}
