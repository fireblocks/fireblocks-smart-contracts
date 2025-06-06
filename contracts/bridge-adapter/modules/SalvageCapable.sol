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
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";

import {LibErrors} from "../../library/Errors/LibErrors.sol";

/**
 * @title SalvageCapable
 * @author Fireblocks
 * @notice This abstract contract provides internal contract logic for rescuing tokens and ETH.
 */
abstract contract SalvageCapable is Context {
	using SafeERC20 for IERC20;

	/// Events
	/**
	 * @notice This event is logged when ERC20 tokens are salvaged.
	 *
	 * @param caller The (indexed) address of the entity that triggered the salvage.
	 * @param token The (indexed) address of the ERC20 token which was salvaged.
	 * @param amount The (indexed) amount of tokens salvaged.
	 */
	event TokenSalvaged(address indexed caller, address indexed token, uint256 amount);

	/**
	 * @notice This event is logged when an NFT is salvaged.
	 *
	 * @param caller The (indexed) address of the entity that triggered the salvage.
	 * @param token The (indexed) address of the ERC721 token which was salvaged.
	 * @param tokenId The (indexed) ID of the NFT which was salvaged.
	 */
	event NFTSalvaged(address indexed caller, address indexed token, uint256 indexed tokenId);

	/**
	 * @notice This event is logged when ETH is salvaged.
	 *
	 * @param caller The (indexed) address of the entity that triggered the salvage.
	 * @param amount The (indexed) amount of ETH salvaged.
	 */
	event GasTokenSalvaged(address indexed caller, uint256 amount);

	/// Functions

	// NOTE: Constructor omitted here

	/**
	 * @notice A function used to salvage ERC20 tokens sent to the contract using this abstract contract.
	 * @dev Calling Conditions:
	 *
	 * - `amount` is greater than 0.
	 *
	 * This function emits a {TokenSalvaged} event, indicating that funds were salvaged.
	 *
	 * @param token The ERC20 asset which is to be salvaged.
	 * @param amount The amount to be salvaged.
	 */
	function salvageERC20(IERC20 token, uint256 amount) external virtual {
		_authorizeSalvageERC20(address(token), amount);
		emit TokenSalvaged(_msgSender(), address(token), amount);
		_withdrawERC20(token, _msgSender(), amount);
	}

	/**
	 * @notice A function used to salvage ETH sent to the contract using this abstract contract.
	 * @dev Calling Conditions:
	 *
	 * - `amount` is greater than 0.
	 *
	 * This function emits a {GasTokenSalvaged} event, indicating that funds were salvaged.
	 *
	 * @param amount The amount to be salvaged.
	 */
	function salvageGas(uint256 amount) external virtual {
		if (amount == 0) {
			revert LibErrors.ZeroAmount();
		}
		_authorizeSalvageGas();
		emit GasTokenSalvaged(_msgSender(), amount);
		(bool succeed, ) = _msgSender().call{value: amount}("");
		if (!succeed) {
			revert LibErrors.SalvageGasFailed();
		}
	}

	/**
	 * @notice A function used to salvage ERC-721 NFTs sent to the contract using this abstract contract.
	 * @dev Calling Conditions:
	 *
	 * - `from` cannot be the zero address (checked by {IERC721}.{safeTransferFrom}).
	 * - `to` cannot be the zero address (checked by {IERC721}.{safeTransferFrom}).
	 * - `tokenId` must exist and be owned by this contract (checked by {IERC721}.{safeTransferFrom}).
	 *
	 * This function emits a {NFTSalvaged} event, indicating that an NFT was salvaged. This function emits {Transfer}
	 * event as a result of the {IERC721}.{safeTransferFrom} call indicating that the NFT was transferred.
	 *
	 * @param token The ERC721 asset which is to be salvaged.
	 * @param tokenId The ID of the NFT which is to be salvaged.
	 */
	function salvageNFT(IERC721 token, uint256 tokenId) external virtual {
		_authorizeSalvageNFT();
		token.safeTransferFrom(address(this), _msgSender(), tokenId);
		emit NFTSalvaged(_msgSender(), address(token), tokenId);
	}

	/**
	 * @notice An internal function used to withdraw ERC20 tokens in the contract.
	 * @dev Internal function without access restriction.
	 *
	 * Calling Conditions:
	 *
	 * - `amount` is greater than 0.
	 *
	 * @param token The ERC20 asset which is to be withdrawn.
	 * @param recipient The address to which the tokens are to be sent.
	 * @param amount The amount to be withdrawn.
	 */
	function _withdrawERC20(IERC20 token, address recipient, uint256 amount) internal virtual {
		if (amount == 0) {
			revert LibErrors.ZeroAmount();
		}
		token.safeTransfer(recipient, amount);
	}

	/**
	 * @notice This function is designed to be overridden in inheriting contracts.
	 * @dev Override this function to implement RBAC control.
	 *
	 * @param salvagedToken The address of the token being salvaged.
	 * @param amount The amount of the token being salvaged.
	 */
	function _authorizeSalvageERC20(address salvagedToken, uint256 amount) internal virtual;

	/**
	 * @notice This function is designed to be overridden in inheriting contracts.
	 * @dev Override this function to implement RBAC control.
	 */
	function _authorizeSalvageGas() internal virtual;

	/**
	 * @notice This function is designed to be overridden in inheriting contracts.
	 * @dev Override this function to implement RBAC control.
	 */
	function _authorizeSalvageNFT() internal virtual;
}
