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
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/draft-IERC6093.sol)
pragma solidity 0.8.20;

/**
 * @dev Standard ERC1155 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC1155 tokens.
 */
interface IERC1155Errors {
	/**
	 * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
	 * @param sender Address whose tokens are being transferred.
	 * @param balance Current balance for the interacting account.
	 * @param needed Minimum amount required to perform a transfer.
	 * @param tokenId Identifier number of a token.
	 */
	error ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId);

	/**
	 * @dev Indicates a failure with the token `sender`. Used in transfers.
	 * @param sender Address whose tokens are being transferred.
	 */
	error ERC1155InvalidSender(address sender);

	/**
	 * @dev Indicates a failure with the token `receiver`. Used in transfers.
	 * @param receiver Address to which tokens are being transferred.
	 */
	error ERC1155InvalidReceiver(address receiver);

	/**
	 * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
	 * @param operator Address that may be allowed to operate on tokens without being their owner.
	 * @param owner Address of the current owner of a token.
	 */
	error ERC1155MissingApprovalForAll(address operator, address owner);

	/**
	 * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
	 * @param approver Address initiating an approval operation.
	 */
	error ERC1155InvalidApprover(address approver);

	/**
	 * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
	 * @param operator Address that may be allowed to operate on tokens without being their owner.
	 */
	error ERC1155InvalidOperator(address operator);

	/**
	 * @dev Indicates an array length mismatch between ids and values in a safeBatchTransferFrom operation.
	 * Used in batch transfers.
	 * @param idsLength Length of the array of token identifiers
	 * @param valuesLength Length of the array of token amounts
	 */
	error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
}
