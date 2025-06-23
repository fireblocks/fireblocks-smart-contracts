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

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {IOFT, OFTCore} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import {SendParam, OFTReceipt, MessagingReceipt, MessagingFee} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {RoleBasedOwnable} from "./modules/RoleBasedOwnable.sol";
import {PauseCapable} from "./modules/PauseCapable.sol";
import {SalvageCapable} from "./modules/SalvageCapable.sol";
import {IERC20MintableBurnable} from "./interfaces/IERC20MintableBurnable.sol";
import {LibErrors} from "../library/Errors/LibErrors.sol";

/**
 * @title FungibleLayerZeroAdapter
 * @author Fireblocks
 * @notice This contract is an adapter for an ERC-20 token to LayerZero OFT (Omnichain Fungible Token) functionality for
   cross-chain token bridging.
 * @dev This contract serves as an adapter for an ERC-20 token, providing integration with LayerZero protocol
 * to enable cross-chain token bridging. When a user initiates a bridge transaction, this contract:
 * 1. Transfers tokens from the user to itself (requires user allowance)
 * 2. Burns the tokens
 * 3. Sends a message to LayerZero to be relayed to the peer on destination chain
 *
 * Configuration:
 *
 * - This contract requires the following parameters to be set during deployment:
 *   - Token address: The address of the token to be bridged
 *   - LayerZero endpoint: The address of the LayerZero protocol endpoint that facilitates cross-chain messaging
 *   - Delegate address: The address authorized to perform privileged operations on behalf of this contract
 *   - Default admin: The address that will be granted the DEFAULT_ADMIN_ROLE, allowing it to manage roles and permissions
 *   - Pauser: The address that will be granted the PAUSER_ROLE, allowing it to pause and unpause the contract
 * - This contract must be granted the minting and burning privileges from the token to be bridged.
 * - Peers must be properly configured across chains to establish trusted relationships
 *
 * Preconditions for bridging:
 *
 * - User must approve sufficient token allowance to this adapter
 * - Destination chain must have a corresponding adapter deployed and properly configured
 * - The peer for the destination chain must exist
 * - Assumes lossless 1:1 transfers (no fees on token transfer)
 */
contract FungibleLayerZeroAdapter is OFTCore, RoleBasedOwnable, PauseCapable, SalvageCapable {
	using SafeERC20 for IERC20MintableBurnable;
	using EnumerableMap for EnumerableMap.AddressToUintMap;

	/// Types

	/**
	 * @notice Struct type to represent a pair of endpoint ID and peer address.
	 * @dev Struct type to represent a pair of endpoint ID and peer address.
	 * @param endpointId The endpoint ID
	 * @param peer The peer address
	 */
	struct PeerInfo {
		uint32 endpointId;
		bytes32 peer;
	}

	/// Constants

	/**
	 * @notice The Access Control identifier for the Pauser Role.
	 * An account with "PAUSER_ROLE" can pause the contract.
	 *
	 * @dev This constant holds the hash of the string "PAUSER_ROLE".
	 */
	bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

	/**
	 * @notice The Access Control identifier for the Embargo Role.
	 * An account with "EMBARGO_ROLE" can perform operations related to the management of embargoed tokens,
	 * such as recovering embargoed tokens.
	 *
	 * @dev This constant holds the hash of the string "EMBARGO_ROLE".
	 */
	bytes32 public constant EMBARGO_ROLE = keccak256("EMBARGO_ROLE");

	/**
	 * @notice The Access Control identifier for the Contract Admin Role.
	 * An account with "CONTRACT_ADMIN_ROLE" can perform all the operations that were
	 * originally dependent on `onlyOwner` in the OFT contract.
	 *
	 * @dev This constant holds the hash of the string "CONTRACT_ADMIN_ROLE".
	 */
	bytes32 public constant CONTRACT_ADMIN_ROLE = keccak256("CONTRACT_ADMIN_ROLE");

	/**
	 * @notice The Access Control identifier for the Salvage Role.
	 * An account with "SALVAGE_ROLE" can perform operations related to the recovery of tokens
	 * that are not part of the OFT functionality, such as recovering tokens
	 * that are not the inner token of this adapter.
	 * @dev This constant holds the hash of the string "SALVAGE_ROLE".
	 */
	bytes32 public constant SALVAGE_ROLE = keccak256("SALVAGE_ROLE");

	/// State

	/**
	 * @notice The ERC-20 token adapted for OFT functionality.
	 * @dev This token is the underlying asset that will be bridged across chains.
	 */
	IERC20MintableBurnable internal immutable innerToken;

	/**
	 * @notice This is an array to store endpoint IDs that correspond to peers configured in {OAppCore}.{peers}
	 * mapping.
	 * @dev This array enables efficient enumeration of all endpoint IDs with configured peers. This is useful for
	 * tracking and retrieving all connected chains for this adapter.
	 */
	uint32[] private _peerEids;

	/**
	 * @notice Mapping that tracks embargoed token balances by address.
	 * @dev Stores tokens that couldn't be transferred to their intended recipients. When a token transfer fails during
	 * bridging operations, the tokens are held in this contract and recorded in this ledger until they can be properly
	 * released or recovered.
	 * Maps addresses to token amounts, using OpenZeppelin's {EnumerableMap}.{AddressToUintMap} data structure.
	 * This provides enumeration capabilities alongside the standard mapping functionality.
	 */
	EnumerableMap.AddressToUintMap internal _embargoLedger;

	/**
	 * @notice The total amount of tokens currently embargoed in this contract.
	 * @dev This variable keeps track of the total amount of tokens that are currently locked in the embargo ledger.
	 * It is updated whenever tokens are added or removed from the ledger.
	 */
	uint256 private totalEmbargoedBalance;

	/// Events

	/**
	 * @notice This event is emitted when a transfer fails and the funds are locked in the contract.
	 *
	 * @param recipient The (indexed) address of the intended recipient
	 * @param bError The error message in bytes
	 * @param amount The amount of tokens that are locked
	 */
	event EmbargoLock(address indexed recipient, bytes bError, uint256 amount);

	/**
	 * @notice This event is emitted when embargoed tokens are released.
	 *
	 * @param caller The (indexed) address of the caller
	 * @param embargoedAccount The (indexed) address of the account that had embargoed balance locked in this contract.
	 * @param _to The (indexed) address of the recipient
	 * @param amount The amount of tokens that are released
	 */
	event EmbargoRelease(address indexed caller, address indexed embargoedAccount, address indexed _to, uint256 amount);

	/// Functions

	/**
	 * @notice Constructor for the FungibleLayerZeroAdapter contract.
	 * @dev Initializes the OFTAdapter contract with token and LayerZero configuration.
	 * @param _token The address of the ERC-20 token that this adapter is used for.
	 * @param _lzEndpoint The LayerZero endpoint contract address.
	 * @param _delegate The delegate capable of making OApp configurations regarding this contract on the LayerZero 
	 * endpoint contract. This account will be granted the CONTRACT_ADMIN_ROLE.
	 * @param defaultAdmin The address to be granted the DEFAULT_ADMIN_ROLE.
	 * @param pauser The address to be granted the PAUSER_ROLE.
	 */
	constructor(
		address _token,
		address _lzEndpoint,
		address _delegate,
		address defaultAdmin,
		address pauser
	) OFTCore(IERC20Metadata(_token).decimals(), _lzEndpoint, _delegate) RoleBasedOwnable() PauseCapable() {
		innerToken = IERC20MintableBurnable(_token);

		// grant admin roles
		_grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
		_grantRole(CONTRACT_ADMIN_ROLE, _delegate);
		_grantRole(PAUSER_ROLE, pauser);
	}

	/**
	 * @dev This is a function used to retrieve the address of the underlying ERC-20 implementation.
	 * @dev Since this contract is an OFTAdapter for a token and not an OFT token itself, address(this) and ERC-20 are
	 * NOT the same address.
	 * @return The address of the being ERC-20 token.
	 */
	function token() public view returns (address) {
		return address(innerToken);
	}

	/**
	 * @notice This function indicates whether the OFT contract requires approval of the 'token()' to send tokens.
	 * @dev In non-default OFTAdapter contracts with something like mint and burn privileges, it would NOT need approval.
	 * @return Always true, as this adapter requires approval for minting and burning.
	 */
	function approvalRequired() external pure virtual returns (bool) {
		return true;
	}

	/**
	 * @notice This function lists all configured peers with their endpoint IDs.
	 * @dev This function returns an array of struct containing endpoint IDs and their corresponding peer addresses.
	 * It's designed for off-chain query support and adapter mesh introspection.
	 * This enumeration function simplifies backend tasks by providing a complete view of the adapter mesh.
	 *
	 * @return peerList An array of {PeerInfo} structs, each containing an endpoint ID and its corresponding peer
	 * address.
	 */
	function listPeers() external view returns (PeerInfo[] memory peerList) {
		{
			uint256 _peerCount = _peerEids.length;
			peerList = new PeerInfo[](_peerCount);

			for (uint256 i = 0; i < _peerCount; ) {
				uint32 eid = _peerEids[i];
				peerList[i] = PeerInfo({endpointId: eid, peer: peers[eid]});
				unchecked {
					++i;
				}
			}
		}
	}

	/**
	 * @notice This function returns the number of peers.
	 * @dev This function is used to retrieve the total count of configured peers.
	 *
	 * @return The total count of configured peers
	 */
	function peerCount() external view virtual returns (uint256) {
		return _peerEids.length;
	}

	/**
	 * @notice This function returns all configured peer endpoint IDs.
	 * @dev This function is used to retrieve all endpoint IDs that have peers configured.
	 *
	 * @return Array of all endpoint IDs that have peers configured
	 */
	function peerEids() external view virtual returns (uint32[] memory) {
		return _peerEids;
	}

	/**
	 * @notice This function returns the amount of tokens locked in the embargo ledger for a specific address.
	 * @dev This function is used to retrieve the amount of tokens that are locked in the embargo ledger for a specific
	 * address.
	 *
	 * This function will return 0 if the address is not found in the embargo ledger.
	 *
	 * @param _account The address to check the embargo balance for.
	 * @return The amount of tokens locked in the embargo ledger for the specified address.
	 */
	function embargoedBalance(address _account) external view returns (uint256) {
		(, uint256 amount) = _embargoLedger.tryGet(_account);
		return amount;
	}

	/**
	 * @notice This function is used to fetch the accounts that have embargoed balances.
	 * @dev This function return an array containing all the keys of the `_embargoLedger` mapping.
	 *
	 * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
	 * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
	 * this function has an unbounded cost, and using it as part of a state-changing function may render the function
	 * uncallable if the map grows to a point where copying to memory consumes too much gas to fit in a block.
	 * This comment is from openzeppelin-contracts/utils/structs/EnumerableMap.sol
	 */
	function embargoedAccounts() external view returns (address[] memory) {
		return _embargoLedger.keys();
	}

	/**
	 * @notice A function used to withdraw `innerToken` balance currently embargoed by the contract, to a specified
	 * `_to` address. The entirety of the `embargoed` account's balance is withdrawn.
	 * @dev Transfers the full amount of embargoed tokens from a specific account to the designated recipient address.
	 * This operation completely clears the embargo balance for the specified account.
	 *
	 * Calling Conditions:
	 * - The `embargoedAddress` must have a non-zero balance embargoed balance in the `_embargoLedger`.
	 * - The caller must have the `EMBARGO_ROLE` to execute this function.
	 *
	 * This function emits an {EmbargoRelease} event as a part of {FungibleLayerZeroAdapter}.{_recoverEmbargoedTokens}
	 * implementation.
	 *
	 * @param embargoedAddress The address of the account that had embargoed balance locked in this contract.
	 * @param _to The address to transfer the tokens to.
	 */
	function recoverEmbargoedTokens(
		address embargoedAddress,
		address _to
	) external virtual whenNotPaused onlyRole(EMBARGO_ROLE) {
		_recoverEmbargoedTokens(embargoedAddress, _to);
	}

	/**
	 * @notice Executes the send operation.
	 * @dev Executes the send operation.
	 *
	 * Calling Conditions:
	 *
	 * - The contract is not paused.
	 *
	 * @param _sendParam The parameters for the send operation.
	 * @param _fee The calculated fee for the send() operation.
	 *   - nativeFee: The native fee.
	 *   - lzTokenFee: The lzToken fee.
	 * @param _refundAddress The address to receive any excess funds.
	 * @return msgReceipt The receipt for the send operation.
	 * MessagingReceipt: LayerZero msg receipt
	 *   - guid: The unique identifier for the sent message.
	 *   - nonce: The nonce of the sent message.
	 *   - fee: The LayerZero fee incurred for the message.
	 * @return oftReceipt The OFT receipt information.
	 */
	function send(
		SendParam calldata _sendParam,
		MessagingFee calldata _fee,
		address _refundAddress
	)
		external
		payable
		virtual
		override
		whenNotPaused
		returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt)
	{
		return _send(_sendParam, _fee, _refundAddress);
	}

	/**
	 * @notice A function used to withdraw `innerToken` balance currently embargoed by the contract to the `embargoed`
	 * account. Used in the scenario where the `embargoed` account is now capable/allowed to hold a balance of
	 * `innerToken`, hence the function has no access control.
	 * @dev Transfers the full amount of embargoed `innerToken` tokens from the `embargoedAddress` account directly
	 * back to the same account, allowing the account to reclaim its tokens. This operation completely clears the
	 * embargo balance in `_embargoLedger` for the specified account.
	 *
	 * Calling Conditions:
	 * - The `embargoedAddress` must have a non-zero balance embargoed balance in the `_embargoLedger`.
	 *
	 * This function emits an {EmbargoRelease} event as a part of {FungibleLayerZeroAdapter}.{_recoverEmbargoedTokens}
	 * implementation.
	 *
	 * @param embargoedAddress The address of the account that had embargoed balance locked in this contract.
	 */
	function releaseEmbargoedTokens(address embargoedAddress) external virtual whenNotPaused {
		_recoverEmbargoedTokens(embargoedAddress, embargoedAddress);
	}

	/**
	 * @notice This function is used to debit tokens from the sender's specified balance.
	 * @dev This function transfers tokens from the sender to this contract, and then burns them.
	 *
	 * Calling Conditions:
	 *
	 * - The sender must approve this contract to spend the specified amount of tokens.
	 * - The sender must have sufficient balance to cover the debit amount.
	 * - The destination chain must be a valid LayerZero endpoint ID.
	 * - The adapter must be granted BURNER_ROLE on the token contract.
	 *
	 * @param _from The address to debit from.
	 * @param _amountLD The amount of tokens to send.
	 * @param _minAmountLD The minimum amount to send.
	 * @param _dstEid The destination chain ID.
	 *
	 * IMPORTANT: This implementation assumes tokens are transferred without any fees or deductions (1:1 ratio).
	 * If the underlying 'innerToken' implements transfer fees, taxation mechanisms, or any other functionality that
	 * alters the amount during transfers, this implementation will fail to account for those differences.
	 * In such cases, this method would need to be overridden to accurately track the actual tokens received
	 * by implementing pre-transfer and post-transfer balance checks.
	 *
	 * This function emits a {OFTSent} event as a part of {OAppCore}.{_send} implementation.
	 *
	 * @return amountSentLD The amount sent from the source chain.
	 * @return amountReceivedLD The amount to be received on the destination chain after any fees, deductions or potential conversions.
	 */
	function _debit(
		address _from,
		uint256 _amountLD,
		uint256 _minAmountLD,
		uint32 _dstEid
	) internal virtual override returns (uint256 amountSentLD, uint256 amountReceivedLD) {
		(amountSentLD, amountReceivedLD) = _debitView(_amountLD, _minAmountLD, _dstEid);
		IERC20MintableBurnable(address(innerToken)).safeTransferFrom(_from, address(this), amountSentLD);
		innerToken.burn(amountSentLD);
	}

	/**
	 * @notice This function is used to credit tokens to itself and transfer them to the specified address.
	 * @dev This function mints tokens to the contract and attempts to transfer them to the specified address.
	 * If the transfer fails, it records the amount in the embargo ledger for later recovery.
	 *
	 * This function might emit an {EmbargoLock} event as a part of {_credit} implementation if the transfer
	 * fails.
	 *
	 * @param _to The address to credit the tokens to.
	 * @param _amountLD The amount of tokens to credit.
	 * @dev _srcEid The source chain ID.
	 *
	 * IMPORTANT: This implementation assumes tokens are transferred without any fees or deductions (1:1 ratio).
	 * If the underlying token implements any mechanism that modifies transfer amounts (such as fees or rebasing),
	 * this implementation will need to be overridden with pre/post balance checks to accurately calculate
	 * the actual amount received.
	 *
	 * This function emits an {OFTReceived} event as a part of {OAppCore}.{_lzReceive} implementation.
	 * @return amountReceivedLD The actual amount of tokens received by the recipient.
	 */
	function _credit(
		address _to,
		uint256 _amountLD,
		uint32 /*_srcEid*/
	) internal virtual override returns (uint256 amountReceivedLD) {
		innerToken.mint(address(this), _amountLD);
		bytes memory data = abi.encodeWithSelector(innerToken.transfer.selector, _to, _amountLD);
		(bool success, bytes memory returnData) = address(innerToken).call(data);

		// Check for success and expected return value (true or empty)
		if (success) {
			if (returnData.length == 0 || abi.decode(returnData, (bool))) {
				return _amountLD;
			}
		}
		// Record in embargo ledger if failed
		(, uint256 currentEmbargo) = _embargoLedger.tryGet(_to);
		_embargoLedger.set(_to, currentEmbargo + _amountLD);
		totalEmbargoedBalance += _amountLD;
		emit EmbargoLock(_to, returnData, _amountLD);
		return _amountLD;
	}

	/**
	 * @notice Override _setPeer to track endpoint IDs in array
	 * @dev This function is called when setting a peer for an endpoint.
	 * It updates the internal mapping and tracks the endpoint IDs in an array.
	 *
	 * This function emits a {PeerSet} event as a part of {OAppCore}.{_setPeer} implementation.
	 *
	 * @param _eid The endpoint ID
	 * @param _peer The address of the peer to be associated with the endpoint
	 */
	function _setPeer(uint32 _eid, bytes32 _peer) internal virtual override {
		bool hadPeerBefore = peers[_eid] != bytes32(0);
		bool isSettingToZero = _peer == bytes32(0);

		// Update our tracking array
		if (!hadPeerBefore && !isSettingToZero) {
			// Adding new peer - add to array
			_peerEids.push(_eid);
		} else if (hadPeerBefore && isSettingToZero) {
			// Removing peer - remove from array
			for (uint256 i = 0; i < _peerEids.length; ) {
				if (_peerEids[i] == _eid) {
					// Replace with the last element and pop
					_peerEids[i] = _peerEids[_peerEids.length - 1];
					_peerEids.pop();
					break;
				}
				unchecked {
					++i;
				}
			}
		}

		// Call parent implementation to update mapping and emit event
		super._setPeer(_eid, _peer);
	}

	/**
	 * @notice This function is used to recover tokens from the embargo ledger.
	 * @dev Transfers the full amount of embargoed tokens from a specific account to the designated recipient address.
	 * This operation completely clears the embargo balance for the specified account. It them emits an
	 * {EmbargoRelease} event.
	 *
	 * Calling Conditions:
	 * - The `_embargoedAccount` must have an embargoed balance in the ledger.
	 *
	 * @param _embargoedAccount The address of the account that had embargoed balance locked in this contract.
	 * @param _to The address to transfer the tokens to.
	 */
	function _recoverEmbargoedTokens(address _embargoedAccount, address _to) internal virtual {
		(bool embargoExists, uint256 embargoAmount) = _embargoLedger.tryGet(_embargoedAccount);
		bool embargoPurged = _embargoLedger.remove(_embargoedAccount);
		totalEmbargoedBalance -= embargoAmount;
		if (!embargoExists && !embargoPurged) revert LibErrors.NoBalance();

		innerToken.safeTransfer(_to, embargoAmount);

		emit EmbargoRelease(_msgSender(), _embargoedAccount, _to, embargoAmount);
	}

	/**
	 * @notice This is a function that applies a role check to guard operations originally dependent on `onlyOwner`.
	 *
	 * @dev Reverts when the caller does not have the "CONTRACT_ADMIN_ROLE".
	 *
	 * By overriding this hook, accounts with the Contract Admin Role receive the same privileges as the owner through
	 * the `onlyOwner` modifier. This grants access to functions such as:
	 *
	 * - `setDelegate`
	 * - `setPeer`
	 * - `setEnforcedOptions`
	 * - `setMsgInspector`
	 * - `setPreCrime`
	 *
	 * Calling Conditions:
	 *
	 * - Only the "CONTRACT_ADMIN_ROLE" can execute.
	 * - The contract is not paused.
	 */
	/* solhint-disable no-empty-blocks */
	function _checkOwner()
		internal
		view
		virtual
		override(Ownable, RoleBasedOwnable)
		whenNotPaused
		onlyRole(CONTRACT_ADMIN_ROLE)
	{}

	/**
	 * @notice This is a function that applies any validations required to allow Role Access operation (like grantRole
	 * or revokeRole ) to be executed.
	 *
	 * @dev Reverts when the {ERC20F} contract is paused.
	 *
	 * Calling Conditions:
	 *
	 * - {ERC20F} is not paused.
	 */
	/* solhint-disable no-empty-blocks */
	function _authorizeRoleManagement() internal virtual override whenNotPaused {}

	/**
	 * @notice This is a function that applies any validations required to allow Pause operations (like pause
	 *         or unpause) to be executed.
	 *
	 * @dev Reverts when the caller does not have the "PAUSER_ROLE".
	 *
	 * Calling Conditions:
	 *
	 * - Only the "PAUSER_ROLE" can execute.
	 */
	/* solhint-disable no-empty-blocks */
	function _authorizePause() internal virtual override onlyRole(PAUSER_ROLE) {}

	/**
	 * @notice This is a function that applies any validations required to allow salvage operations (like salvageGas).
	 *
	 * @dev Reverts when the caller does not have the "SALVAGE_ROLE".
	 *
	 * Calling Conditions:
	 *
	 * - Only the "SALVAGE_ROLE" can execute.
	 * - The contract is not paused.
	 */
	/* solhint-disable no-empty-blocks */
	function _authorizeSalvage() internal virtual whenNotPaused onlyRole(SALVAGE_ROLE) {}

	/**
	 * @notice This is a function that applies any validations required to allow salvageERC20.
	 *
	 * It adds a check to ensure that the amount of `salvagedToken` is not more than the balance of the `innerToken`
	 * minus the total embargoed balance in the `_embargoLedger`. This is to prevent salvaging more tokens than the
	 * contract can actually send out, this only applies when the `salvagedToken` is the same as the `innerToken`.
	 *
	 * @dev Reverts:
	 *  - if `salvagedToken` is the same as `innerToken` and the amount is greater than the balance of the
	 *    `innerToken` minus the total embargoed balance in the `_embargoLedger`.
	 *  - as per `_authorizeSalvage()`
	 *
	 * @param salvagedToken The address of the token being salvaged.
	 * @param amount The amount of tokens being salvaged.
	 */
	function _authorizeSalvageERC20(address salvagedToken, uint256 amount) internal virtual override {
		_authorizeSalvage();
		if (salvagedToken == address(innerToken)) {
			if (
				innerToken.balanceOf(address(this)) <= totalEmbargoedBalance ||
				amount > innerToken.balanceOf(address(this)) - totalEmbargoedBalance
			) {
				// If the contract balance is not greater than the sum of embargoed balances, revert
				revert LibErrors.UnauthorizedTokenManagement();
			}
		}
	}

	/**
	 * @notice This is a function that applies any validations required to allow salvageGas.
	 *
	 * @dev Reverts as per `_authorizeSalvage()`.
	 */
	function _authorizeSalvageGas() internal virtual override {
		_authorizeSalvage();
	}

	/**
	 * @notice This is a function that applies any validations required to allow salvageNFT.
	 *
	 * @dev Reverts as per `_authorizeSalvage()`.
	 */
	function _authorizeSalvageNFT() internal virtual override {
		_authorizeSalvage();
	}
}
