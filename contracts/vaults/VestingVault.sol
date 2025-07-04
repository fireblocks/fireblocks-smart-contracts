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

import {IERC20} from "@openzeppelin/contracts-v5/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts-v5/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts-v5/access/AccessControl.sol";
import {Context} from "@openzeppelin/contracts-v5/utils/Context.sol";
import {IVestingVault} from "./interfaces/IVestingVault.sol";
import {IVestingVaultErrors} from "./interfaces/IVestingVaultErrors.sol";
import {SalvageCapable} from "../library/Utils/SalvageCapable.sol";
import {LibErrors} from "../library/Errors/LibErrors.sol";

/**
 * @title VestingVault
 * @author Fireblocks
 * @notice This contract manages token vesting schedules with support for multiple periods per schedule
 *         and granular claiming at beneficiary, schedule, and period levels
 *
 * @dev The contract manages its own schedule IDs, simplifying data validation and analytics.
 *      Schedules are stored in a mapping by ID and beneficiaries have arrays of their schedule IDs.
 *      Each schedule can contain multiple vesting periods with different parameters.
 *
 *      The contract supports both global and individual vesting modes:
 *      - Global mode: All schedules start relative to a global start time
 *      - Individual mode: Each schedule has absolute start/end times
 *
 *      This contract is non-upgradeable for security and immutability as per design requirements.
 *
 *      Access control roles:
 *      - VESTING_ADMIN_ROLE: Can create schedules and start global vesting
 *      - FORFEITURE_ADMIN_ROLE: Can cancel vesting schedules
 *      - DEFAULT_ADMIN_ROLE: Can manage roles and perform salvage operations
 *
 *      Limitations:
 *      - Rebasing tokens are NOT supported. This contract assumes token balances remain constant
 *        except through explicit transfers. Rebasing tokens automatically adjust all holder balances (up or down),
 *        which would break vesting accounting as the contract tracks fixed amounts at schedule creation. Using
 *        rebasing tokens will lead to potential loss of funds.
 *      - Maximum of (2^32 - 1) vesting schedules.
 *
 * @custom:security-contact support@fireblocks.com
 */
contract VestingVault is Context, AccessControl, SalvageCapable, IVestingVault, IVestingVaultErrors {
    using SafeERC20 for IERC20;

    /// Constants

    /**
     * @notice The Access Control identifier for the Vesting Admin Role.
     * @dev Accounts with this role can create schedules and start global vesting
     */
    bytes32 public constant VESTING_ADMIN_ROLE = keccak256("VESTING_ADMIN_ROLE");

    /**
     * @notice The Access Control identifier for the Forfeiture Admin Role.
     * @dev Accounts with this role can cancel vesting schedules
     */
    bytes32 public constant FORFEITURE_ADMIN_ROLE = keccak256("FORFEITURE_ADMIN_ROLE");

    /**
     * @notice The Access Control identifier for the Salvager Role.
     * @dev An account with "SALVAGE_ROLE" can salvage tokens and gas.
     */
    bytes32 public constant SALVAGE_ROLE = keccak256("SALVAGE_ROLE");

    /// State - Immutable

    /**
     * @notice The ERC20 token being vested
     * @dev Set during construction and cannot be changed
     */
    IERC20 public immutable vestingToken;

    /**
     * @notice Whether the contract operates in global vesting mode
     * @dev In global mode, schedule times are relative to globalVestingStartTime
     *      In individual mode, schedule times are absolute timestamps
     */
    bool public immutable globalVestingMode;

    /// State - Mutable

    /**
     * @notice Timestamp when global vesting started
     * @dev Only relevant when globalVestingMode is true
     */
    uint64 public globalVestingStartTime;

    /**
     * @notice Whether global vesting has been started
     * @dev Used to track if the global vesting has begun
     */
    bool public globalVestingStarted;

    /**
     * @notice Counter for generating unique schedule IDs
     * @dev Incremented for each new schedule created
     */
    uint32 public scheduleCounter;

    /**
     * @notice Mapping from schedule ID to schedule data
     * @dev Primary storage for all schedules
     */
    mapping(uint256 => Schedule) public scheduleById;

    /**
     * @notice Mapping from beneficiary address to their schedule IDs
     * @dev Enables querying all schedules for a beneficiary
     */
    mapping(address => uint32[]) public beneficiaryToScheduleIds;

    /**
     * @notice Current amount of tokens committed to vesting schedules
     * @dev Represents the sum of all unclaimed tokens across all active schedules.
     *      Increases when schedules are created, decreases when tokens are released or forfeited.
     */
    uint256 public committedTokens;

    /// Functions

    /**
     * @notice Constructs the VestingVault contract
     * @dev Initializer function that sets up the token to manage in the vault, RBAC roles, and Global Vesting Mode.
     *
     * The FORFEITURE_ADMIN_ROLE and SALVAGE_ROLE are not granted at deploy time and must be granted separately when
     * cancellation or salvage functionality is needed.
     *
     * Calling Conditions:
     *
     * - `vestingToken_` must have bytecode set and must implement the `decimals()` function of ERC20, with a
     *   return value > 0
     * - `defaultAdmin` must not be the zero address
     * - `vestingAdmin` must not be the zero address
     *
     * Warning:
     * - This contract does not support rebasing tokens. Using rebasing tokens will lead to potential loss of funds.
     *
     * @param vestingToken_ Address of the ERC20 token to be vested
     * @param globalVestingMode_ Whether to use global vesting mode
     * @param defaultAdmin Address to be granted DEFAULT_ADMIN_ROLE
     * @param vestingAdmin Address to be granted VESTING_ADMIN_ROLE
     */
    constructor(address vestingToken_, bool globalVestingMode_, address defaultAdmin, address vestingAdmin) {
        require(defaultAdmin != address(0), LibErrors.InvalidAddress());
        require(vestingAdmin != address(0), LibErrors.InvalidAddress());

        // Validate that vestingToken_ passes common ERC20 implementation checks
        require(vestingToken_.code.length > 0, LibErrors.InvalidImplementation());
        // Check if decimals() function exists and returns > 0
        (bool success, bytes memory data) = vestingToken_.staticcall(abi.encodeWithSignature("decimals()"));
        require(success && data.length > 0, LibErrors.InvalidImplementation());
        uint8 decimals = abi.decode(data, (uint8));
        require(decimals > 0, LibErrors.InvalidImplementation());

        vestingToken = IERC20(vestingToken_);
        globalVestingMode = globalVestingMode_;

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(VESTING_ADMIN_ROLE, vestingAdmin);
    }

    /// External Functions - Vesting Management

    /**
     * @notice Creates a vesting schedule for a beneficiary
     * @dev Creates a new vesting schedule with the specified periods. Each schedule gets a unique ID.
     *      All vesting periods must have non-zero amounts as zero-amount periods provide no value
     *      and can create confusion in vesting calculations and gas inefficiencies.
     *
     * Calling Conditions:
     *
     * - The caller must have `VESTING_ADMIN_ROLE`
     * - `beneficiary` must not be the zero address
     * - `periods` array must not be empty
     *
     * Additional validations that may cause reverts:
     * - The contract must have sufficient token balance to cover the total schedule amount
     * - If global vesting mode is off, each period's `startPeriod` must be >= current timestamp
     * - For each period:
     *   - `amount` must be greater than zero
     *   - `endPeriod` must be greater than `startPeriod`
     *   - If the period has a cliff, `startPeriod + cliff` must not exceed `endPeriod`
     *
     * Note maximum 4,294,967,295 (2^32 - 1) vesting schedules can be created due to uint32 scheduleCounter, though
     * this limit is unlikely to be reached in practice.
     *
     * @param beneficiary Address of the beneficiary who will receive vested tokens
     * @param isCancellable Whether this schedule can be cancelled by admins
     * @param periods Array of vesting periods for the schedule
     * @return scheduleId The ID of the created schedule
     */
    function createSchedule(
        address beneficiary,
        bool isCancellable,
        VestingPeriod[] calldata periods
    ) external override onlyRole(VESTING_ADMIN_ROLE) returns (uint32 scheduleId) {
        // Validate inputs
        if (beneficiary == address(0)) revert LibErrors.InvalidAddress();
        if (periods.length == 0) revert LibErrors.InvalidArrayLength();

        // Generate new schedule ID and initialize storage
        scheduleId = ++scheduleCounter;
        Schedule storage newSchedule = scheduleById[scheduleId];
        newSchedule.id = scheduleId;
        newSchedule.beneficiary = beneficiary;
        newSchedule.isCancellable = isCancellable;
        newSchedule.isCancelled = false;

        // Validate periods and copy to storage in single loop
        uint256 totalAmount = 0;
        uint256 periodsLength = periods.length;
        for (uint256 i = 0; i < periodsLength; ) {
            VestingPeriod calldata period = periods[i];

            // Validate period amount
            if (period.amount == 0) revert LibErrors.ZeroAmount();

            // Validate period times
            if (period.endPeriod <= period.startPeriod) revert IVestingVaultErrors.InvalidEndTime(i, period.endPeriod);

            // Validate cliff doesn't exceed vesting duration
            if (period.cliff > 0 && period.startPeriod + period.cliff > period.endPeriod) {
                revert IVestingVaultErrors.InvalidCliff(i, period.cliff);
            }

            // In non-global mode, validate start time is not in the past
            if (!globalVestingMode && period.startPeriod < block.timestamp) {
                revert IVestingVaultErrors.InvalidStartTime(i, period.startPeriod);
            }

            // Store period and accumulate total amount
            newSchedule.periods.push(period);
            totalAmount += period.amount;
            unchecked {
                ++i;
            }
        }

        // Check contract has sufficient uncommitted balance
        uint256 contractBalance = vestingToken.balanceOf(address(this));
        uint256 availableBalance = contractBalance - committedTokens;

        if (availableBalance < totalAmount)
            revert IVestingVaultErrors.InsufficientBalance(contractBalance, availableBalance);

        // Add schedule ID to beneficiary's list and update committed tokens
        beneficiaryToScheduleIds[beneficiary].push(scheduleId);
        committedTokens += totalAmount;

        // Emit event with the complete schedule
        emit VestingScheduleCreated(msg.sender, beneficiary, scheduleId, newSchedule);
    }

    /**
     * @notice Starts global vesting for all schedules
     * @dev Marks the beginning of the global vesting period. All schedules' periods will be
     *      calculated relative to this timestamp.
     *
     * Calling Conditions:
     *
     * - The caller must have `VESTING_ADMIN_ROLE`
     * - `globalVestingMode` must be true
     * - Global vesting must not have already been started
     *
     * Emits a {GlobalVestingStarted} event.
     */
    function startGlobalVesting() external override onlyRole(VESTING_ADMIN_ROLE) {
        // Ensure global vesting mode is enabled
        require(globalVestingMode, IVestingVaultErrors.GlobalVestingNotEnabled());
        // Check global vesting hasn't already started
        require(!globalVestingStarted, IVestingVaultErrors.GlobalVestingAlreadyStarted());

        // Set global vesting as started
        globalVestingStarted = true;
        globalVestingStartTime = uint64(block.timestamp);
        // Emit event
        emit GlobalVestingStarted(block.timestamp);
    }

    /// External Functions - Token Claiming (Beneficiary Level)

    /**
     * @notice Claims all available vested tokens for the caller across all schedules. Only the beneficiary
     *         of the schedule can claim their tokens.
     * @dev Iterates through all schedules and periods to calculate total claimable amount.
     *      Updates the claimed amounts for each period.
     *
     * Calling Conditions:
     *
     * - If global vesting mode is enabled, global vesting must have been started
     *
     * Reverts if:
     *
     * - There are no schedules for the caller
     * - There are no tokens available to be claimed for the any of the beneficiary's schedules
     *
     * Emits {TokenRelease} events for each schedule and period with claimable tokens.
     */
    function claim() external override {
        // Check global vesting status if in global mode
        if (globalVestingMode && !globalVestingStarted) {
            revert IVestingVaultErrors.GlobalVestingNotStarted();
        }

        address beneficiary = _msgSender();
        uint32[] memory scheduleIds = beneficiaryToScheduleIds[beneficiary];
        uint256 scheduleCount = scheduleIds.length;

        if (scheduleCount == 0) {
            revert IVestingVaultErrors.NoTokensToClaim();
        }

        uint256 totalClaimable = 0;

        // Process each schedule
        for (uint256 i = 0; i < scheduleCount; ) {
            uint32 scheduleId = scheduleIds[i];
            Schedule storage schedule = scheduleById[scheduleId];
            // Skip cancelled schedules
            if (schedule.isCancelled) {
                unchecked {
                    ++i;
                }
                continue;
            }
            // Process each period in the schedule
            uint256 numPeriods = schedule.periods.length;
            for (uint256 j = 0; j < numPeriods; ) {
                uint256 claimableAmount = _claim(schedule, scheduleId, j);
                totalClaimable += claimableAmount;
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }

        if (totalClaimable == 0) {
            revert IVestingVaultErrors.NoTokensToClaim();
        }
        // Transfer all claimable tokens
        _processTokenRelease(beneficiary, totalClaimable);
    }

    /**
     * @notice Claims available vested tokens for a specific schedule. Only the beneficiary
     *         of the schedule can claim their tokens.
     * @dev Claims from all periods within the specified schedule.
     *
     * Calling Conditions:
     *
     * - If global vesting mode is enabled, global vesting must have been started
     * - The schedule must exist
     * - The schedule must belong to the caller
     *
     * Reverts if:
     * - There are no tokens available to be claimed for the specified schedule
     *
     * Emits {TokenRelease} events for each period with claimable tokens as part of {_claim}.
     *
     * @param scheduleId The ID of the schedule to claim from
     */
    function claim(uint256 scheduleId) external override {
        // Check global vesting status if in global mode
        if (globalVestingMode && !globalVestingStarted) {
            revert IVestingVaultErrors.GlobalVestingNotStarted();
        }

        Schedule storage schedule = scheduleById[scheduleId];
        address scheduleBeneficiary = schedule.beneficiary;
        // Validate schedule exists
        require(schedule.id != 0, LibErrors.NotFound(scheduleId));
        // Validate schedule belongs to caller
        require(_msgSender() == scheduleBeneficiary, LibErrors.UnauthorizedCaller());

        uint256 totalClaimable = 0;
        uint256 numPeriods = schedule.periods.length;
        // Process each period in the schedule
        for (uint256 i = 0; i < numPeriods; ) {
            uint256 claimableAmount = _claim(schedule, scheduleId, i);
            totalClaimable += claimableAmount;
            unchecked {
                ++i;
            }
        }

        if (totalClaimable == 0) {
            revert IVestingVaultErrors.NoTokensToClaim();
        }
        // Transfer all claimable tokens
        _processTokenRelease(scheduleBeneficiary, totalClaimable);
    }

    /**
     * @notice Claims available vested tokens for a specific period within a schedule. Only the beneficiary
     *         of the schedule can claim their tokens.
     * @dev Most granular claim function - claims from a single period.
     *
     * Calling Conditions:
     *
     * - If global vesting mode is enabled, global vesting must have been started
     * - The schedule must exist
     * - The schedule must belong to the caller
     * - The period index must be valid, i.e. within the periods array bounds
     *
     * Reverts if:
     * - There are no tokens available to be claimed for the specified period
     *
     * Emits a {TokenRelease} event as part of {_claim}.
     *
     * @param scheduleId The ID of the schedule
     * @param periodIndex The index of the period within the schedule
     */
    function claim(uint256 scheduleId, uint256 periodIndex) external override {
        // Check global vesting status if in global mode
        if (globalVestingMode && !globalVestingStarted) {
            revert IVestingVaultErrors.GlobalVestingNotStarted();
        }

        Schedule storage schedule = scheduleById[scheduleId];
        address scheduleBeneficiary = schedule.beneficiary;
        // Validate schedule exists
        require(schedule.id != 0, LibErrors.NotFound(scheduleId));
        // Validate schedule belongs to caller
        require(_msgSender() == scheduleBeneficiary, LibErrors.UnauthorizedCaller());
        // Check if periodIndex is within bounds
        require(
            periodIndex < schedule.periods.length,
            IVestingVaultErrors.InvalidVestingPeriodIndex(scheduleId, periodIndex)
        );
        // Process the specific period
        uint256 claimableAmount = _claim(schedule, scheduleId, periodIndex);
        if (claimableAmount == 0) {
            revert IVestingVaultErrors.NoTokensToClaim();
        }
        // Transfer tokens
        _processTokenRelease(scheduleBeneficiary, claimableAmount);
    }

    /// External Functions - Token Release (Admin Level)

    /**
     * @notice Releases all available vested tokens for a beneficiary across all schedules
     * @dev Admin function to release tokens on behalf of a beneficiary. Useful for
     *      beneficiaries who cannot claim themselves. Iterates through all schedules
     *      and periods to calculate total releasable amount.
     *
     * Calling Conditions:
     *
     * - The caller must have `VESTING_ADMIN_ROLE`
     * - If global vesting mode is enabled, global vesting must have been started
     *
     * Reverts if:
     *
     * - `beneficiary` has no vesting schedules
     * - There are no tokens available to be released for any of the beneficiary's schedules
     *
     * Emits {TokenRelease} events for each schedule and period with releasable tokens.
     *
     * @param beneficiary The beneficiary to release tokens for
     */
    function release(address beneficiary) external override onlyRole(VESTING_ADMIN_ROLE) {
        // Check global vesting status if in global mode
        if (globalVestingMode && !globalVestingStarted) {
            revert IVestingVaultErrors.GlobalVestingNotStarted();
        }

        uint32[] memory scheduleIds = beneficiaryToScheduleIds[beneficiary];
        uint256 scheduleCount = scheduleIds.length;

        if (scheduleCount == 0) {
            revert IVestingVaultErrors.NoTokensToClaim();
        }

        uint256 totalReleasable = 0;

        // Process each schedule
        for (uint256 i = 0; i < scheduleCount; ) {
            uint32 scheduleId = scheduleIds[i];
            Schedule storage schedule = scheduleById[scheduleId];

            // Skip cancelled schedules
            if (schedule.isCancelled) {
                unchecked {
                    ++i;
                }
                continue;
            }
            // Process each period in the schedule
            uint256 numPeriods = schedule.periods.length;
            for (uint256 j = 0; j < numPeriods; ) {
                uint256 releasableAmount = _claim(schedule, scheduleId, j);
                totalReleasable += releasableAmount;
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }

        if (totalReleasable == 0) {
            revert IVestingVaultErrors.NoTokensToClaim();
        }

        // Transfer all releasable tokens
        _processTokenRelease(beneficiary, totalReleasable);
    }

    /**
     * @notice Releases available vested tokens for a specific schedule
     * @dev Admin function to release tokens from a specific schedule on behalf of the beneficiary.
     *      Releases from all periods within the specified schedule.
     *
     * Calling Conditions:
     *
     * - The caller must have `VESTING_ADMIN_ROLE`
     * - If global vesting mode is enabled, global vesting must have been started
     * - The schedule must exist
     *
     * Reverts if:
     * - There are no tokens available to be released for the specified schedule
     *
     * Emits {TokenRelease} events for each period with releasable tokens as part of {_claim}.
     *
     * @param scheduleId The ID of the schedule to release from
     */
    function release(uint256 scheduleId) external override onlyRole(VESTING_ADMIN_ROLE) {
        // Check global vesting status if in global mode
        if (globalVestingMode && !globalVestingStarted) {
            revert IVestingVaultErrors.GlobalVestingNotStarted();
        }

        Schedule storage schedule = scheduleById[scheduleId];
        address scheduleBeneficiary = schedule.beneficiary;
        // Validate schedule exists
        require(schedule.id != 0, LibErrors.NotFound(scheduleId));

        uint256 totalReleasable = 0;
        uint256 numPeriods = schedule.periods.length;

        // Process each period in the schedule
        for (uint256 i = 0; i < numPeriods; ) {
            uint256 releasableAmount = _claim(schedule, scheduleId, i);
            totalReleasable += releasableAmount;
            unchecked {
                ++i;
            }
        }

        if (totalReleasable == 0) {
            revert IVestingVaultErrors.NoTokensToClaim();
        }

        // Transfer all releasable tokens
        _processTokenRelease(scheduleBeneficiary, totalReleasable);
    }

    /**
     * @notice Releases available vested tokens for a specific period within a schedule
     * @dev Admin function to release tokens from a specific period on behalf of the beneficiary.
     *      Most granular release function - releases from a single period.
     *
     * Calling Conditions:
     *
     * - The caller must have `VESTING_ADMIN_ROLE`
     * - If global vesting mode is enabled, global vesting must have been started
     * - The schedule must exist
     * - The period index must be valid (within the periods array bounds)
     *
     * Reverts if:
     * - There are no tokens available to be released for the specified period
     *
     * Emits a {TokenRelease} event as part of {_claim}.
     *
     * @param scheduleId The ID of the schedule
     * @param periodIndex The index of the period within the schedule
     */
    function release(uint256 scheduleId, uint256 periodIndex) external override onlyRole(VESTING_ADMIN_ROLE) {
        // Check global vesting status if in global mode
        if (globalVestingMode && !globalVestingStarted) {
            revert IVestingVaultErrors.GlobalVestingNotStarted();
        }

        Schedule storage schedule = scheduleById[scheduleId];
        address scheduleBeneficiary = schedule.beneficiary;
        // Validate schedule exists
        require(schedule.id != 0, LibErrors.NotFound(scheduleId));
        // Check if periodIndex is within bounds
        require(
            periodIndex < schedule.periods.length,
            IVestingVaultErrors.InvalidVestingPeriodIndex(scheduleId, periodIndex)
        );
        // Process the specific period
        uint256 releasableAmount = _claim(schedule, scheduleId, periodIndex);

        if (releasableAmount == 0) {
            revert IVestingVaultErrors.NoTokensToClaim();
        }

        // Transfer tokens
        _processTokenRelease(scheduleBeneficiary, releasableAmount);
    }

    /// External Functions - Schedule Cancellation

    /**
     * @notice Cancels a vesting schedule by distributing vested tokens and withdrawing unvested tokens
     * @dev Calculates vested amounts up to the current time, transfers them to the beneficiary,
     *      and reclaims unvested tokens to the admin. The schedule is permanently marked as cancelled.
     *
     * Calling Conditions:
     *
     * - The caller must have `FORFEITURE_ADMIN_ROLE`
     * - The schedule must exist
     * - The schedule must be marked as `isCancellable`
     * - The schedule must not already be cancelled
     *
     * Emits a {VestingScheduleCancelled} event.
     *
     * @param scheduleId The ID of the schedule to cancel
     */
    function cancelSchedule(uint256 scheduleId) external override onlyRole(FORFEITURE_ADMIN_ROLE) {
        Schedule storage schedule = scheduleById[scheduleId];

        // Validate schedule exists
        require(schedule.id != 0, LibErrors.NotFound(scheduleId));
        // Check if schedule is cancellable
        require(schedule.isCancellable, IVestingVaultErrors.IrrevocableSchedule(scheduleId));
        // Check if already cancelled
        require(!schedule.isCancelled, IVestingVaultErrors.CancelledSchedule(scheduleId));
        // Cache beneficiary address
        address beneficiary = schedule.beneficiary;

        uint256 claimAmount = 0;
        uint256 forfeitAmount = 0;

        // Calculate vested and total amounts across all periods
        uint256 periodsLength = schedule.periods.length;
        for (uint256 i = 0; i < periodsLength; ) {
            VestingPeriod storage period = schedule.periods[i];

            // Skip fully claimed periods
            if (period.claimedAmount == period.amount) {
                unchecked {
                    ++i;
                }
                continue;
            }
            // Claim any vested amount
            uint256 claimableAmount = _claim(schedule, scheduleId, i);
            claimAmount += claimableAmount;

            // Calculate unvested amount (total - already claimed)
            uint256 unvestedAmount = period.amount - period.claimedAmount;
            forfeitAmount += unvestedAmount;

            // Mark the full period as claimed to prevent future claims
            period.claimedAmount = period.amount;

            unchecked {
                ++i;
            }
        }
        // Mark schedule as cancelled
        schedule.isCancelled = true;

        // Transfer any unclaimed vested tokens to beneficiary
        if (claimAmount > 0) {
            _processTokenRelease(beneficiary, claimAmount);
        }
        // Transfer unvested tokens back to admin
        if (forfeitAmount > 0) {
            _processTokenRelease(_msgSender(), forfeitAmount);
        }
        // Emit event
        emit VestingScheduleCancelled(_msgSender(), beneficiary, scheduleId, claimAmount, forfeitAmount);
    }

    /// External Functions - View Functions

    /**
     * @notice Returns all schedules for a beneficiary
     * @dev Returns a copy of the schedules array to prevent external modification.
     *      Includes both active and cancelled schedules.
     *
     * Note: This operation will copy the entire storage to memory, which can be quite expensive. This is designed to
     * mostly be used by view accessors that are queried without any gas fees (e.g. off-chain via RPC). Do not call
     * this function from other contracts. Instead, the recommended pattern is use `getScheduleIds` if the goal is to
     * enumerate the schedules for a beneficiary
     *
     * @param beneficiary The beneficiary address
     * @return schedules Array of schedules for the beneficiary
     */
    function getSchedules(address beneficiary) external view override returns (Schedule[] memory schedules) {
        uint32[] memory scheduleIds = beneficiaryToScheduleIds[beneficiary];
        schedules = new Schedule[](scheduleIds.length);

        for (uint256 i = 0; i < scheduleIds.length; ) {
            schedules[i] = scheduleById[scheduleIds[i]];
            unchecked {
                ++i;
            }
        }

        return schedules;
    }

    /**
     * @notice Returns a specific schedule by ID
     * @dev Retrieves the complete schedule information including all periods.
     *
     * Note this view function reverts if:
     *
     * - The schedule with `scheduleId` does not exist
     *
     * @param scheduleId The ID of the schedule
     * @return schedule The schedule with the specified ID
     */
    function getSchedule(uint256 scheduleId) external view override returns (Schedule memory schedule) {
        schedule = scheduleById[scheduleId];
        if (schedule.id == 0) revert LibErrors.NotFound(scheduleId);
        return schedule;
    }

    /**
     * @notice Returns all schedule IDs for a beneficiary
     * @dev Returns a copy of the schedule IDs array. Useful for iterating through
     *      a beneficiary's schedules without loading all schedule data.
     *
     * @param beneficiary The beneficiary address
     * @return scheduleIds Array of schedule IDs for the beneficiary
     */
    function getScheduleIds(address beneficiary) external view override returns (uint32[] memory scheduleIds) {
        return beneficiaryToScheduleIds[beneficiary];
    }

    /**
     * @notice Returns the total claimable amount for a beneficiary across all schedules
     * @dev Calculates the sum of all vested but unclaimed tokens. Note that cancelled schedules
     *      are fully accounted for as claimed, so they do not contribute to the claimable amount.
     *
     * @param beneficiary The beneficiary address
     * @return claimableAmount Total amount that can be claimed
     */
    function getClaimableAmount(address beneficiary) external view override returns (uint256 claimableAmount) {
        uint32[] memory scheduleIds = beneficiaryToScheduleIds[beneficiary];

        // If global vesting mode is enabled but not started, return 0
        if (globalVestingMode && !globalVestingStarted) {
            return 0;
        }

        // Sum claimable amounts across all schedules
        for (uint256 i = 0; i < scheduleIds.length; ) {
            Schedule memory schedule = scheduleById[scheduleIds[i]];
            claimableAmount += _getClaimableAmountForSchedule(schedule);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Returns the claimable amount for a specific schedule
     * @dev Calculates the sum of vested but unclaimed tokens across all periods
     *      in the schedule. Returns zero for cancelled schedules.
     *
     * @param scheduleId The ID of the schedule
     * @return claimableAmount Amount that can be claimed from the schedule
     */
    function getClaimableAmount(uint256 scheduleId) external view override returns (uint256 claimableAmount) {
        // If global vesting mode is enabled but not started, return 0
        if (globalVestingMode && !globalVestingStarted) {
            return 0;
        }

        Schedule memory schedule = scheduleById[scheduleId];
        if (schedule.id == 0) {
            return 0;
        }

        return _getClaimableAmountForSchedule(schedule);
    }

    /**
     * @notice Returns the claimable amount for a specific period
     * @dev Calculates the vested but unclaimed tokens for a single period.
     *      Returns zero for cancelled schedules or invalid period indices.
     *
     * @param scheduleId The ID of the schedule
     * @param periodIndex The index of the period
     * @return claimableAmount Amount that can be claimed from the period
     */
    function getClaimableAmount(
        uint256 scheduleId,
        uint256 periodIndex
    ) external view override returns (uint256 claimableAmount) {
        // If global vesting mode is enabled but not started, return 0
        if (globalVestingMode && !globalVestingStarted) {
            return 0;
        }

        Schedule memory schedule = scheduleById[scheduleId];
        if (schedule.id == 0 || schedule.isCancelled || periodIndex >= schedule.periods.length) {
            return 0;
        }

        return _getClaimableAmountForPeriod(schedule.periods[periodIndex]);
    }

    /**
     * @notice Returns the available balance for creating new vesting schedules
     * @dev Calculates how many tokens can be committed to new schedules without
     *      exceeding the contract's token balance.
     *
     * @return availableBalance The amount of tokens available for new commitments
     */
    function getAvailableBalance() external view returns (uint256 availableBalance) {
        uint256 contractBalance = vestingToken.balanceOf(address(this));
        // Available balance is current balance minus already committed tokens
        availableBalance = contractBalance > committedTokens ? contractBalance - committedTokens : 0;
    }

    /// Internal Functions - Salvage Authorization

    /**
     * @notice Authorizes ERC20 salvage operations, preventing salvaging of the vesting token to protect locked funds
     * @dev Reverts when:
     * - the caller does not have the "SALVAGE_ROLE".
     * - `salvagedToken` is the same as `vestingToken`
     * @param salvagedToken The address of the token being salvaged
     */
    function _authorizeSalvageERC20(address salvagedToken) internal virtual override {
        require(salvagedToken != address(vestingToken), LibErrors.InvalidAddress());
        _checkRole(SALVAGE_ROLE);
    }

    /**
     * @notice Authorizes gas (ETH) salvage operations
     * @dev Only accounts with SALVAGE_ROLE can salvage ETH
     */
    function _authorizeSalvageGas() internal virtual override {
        _checkRole(SALVAGE_ROLE);
    }

    /**
     * @notice Authorizes NFT salvage operations
     * @dev Only accounts with SALVAGE_ROLE can salvage NFTs
     */
    function _authorizeSalvageNFT() internal virtual override {
        _checkRole(SALVAGE_ROLE);
    }

    /// Internal Functions - Role Management Override

    /**
     * @notice Prevents renouncing the DEFAULT_ADMIN_ROLE
     * @dev Ensures there's always at least one admin who can manage the contract.
     *
     * Calling Conditions:
     *
     * - If `role` is `DEFAULT_ADMIN_ROLE`, the function will revert
     * - For other roles, follows standard AccessControl renunciation rules
     *
     * @param role The role being renounced
     * @param account The account renouncing the role
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        if (role == DEFAULT_ADMIN_ROLE) {
            revert LibErrors.DefaultAdminError();
        }
        super.renounceRole(role, account);
    }

    /**
     * @notice Prevents default admins from revoking their own DEFAULT_ADMIN_ROLE
     * @dev Ensures there's always at least one admin who can manage the contract.
     *      This prevents the bypass of the renounceRole restriction through revokeRole.
     *
     * Calling Conditions:
     *
     * - The `role` parameter can't be `DEFAULT_ADMIN_ROLE`, when the account is the caller
     * - For other role revocations, follows standard AccessControl rules
     *
     * @param role The role being revoked
     * @param account The account from which the role is being revoked
     */
    function revokeRole(bytes32 role, address account) public virtual override {
        if (role == DEFAULT_ADMIN_ROLE && account == _msgSender()) {
            revert LibErrors.DefaultAdminError();
        }
        super.revokeRole(role, account);
    }

    /// Internal Functions - Vesting Calculations

    /**
     * @notice Marks the amount of unclaimed vested tokens as claimed, for a specific period within a schedule
     * @dev Most granular claim function - claims from a single period.
     *
     * Internal function without access control checks. It performs checks and effects, but doesn't perform
     * any interactions such as external calls to transfer tokens. This falls under the responsibility of
     * the entry-point function, to minimize total calls.
     *
     * Preconditions (unchecked):
     *
     * - The schedule must exist
     * - If global vesting mode is enabled, global vesting must have been started
     * - The period index must be valid (within the vesting periods size)
     *
     * Emits a {TokenRelease} event.
     *
     * @param schedule The schedule storage reference
     * @param scheduleId The ID of the schedule (for event emission)
     * @param periodIndex The index of the period within the schedule
     */
    function _claim(
        Schedule storage schedule,
        uint256 scheduleId,
        uint256 periodIndex
    ) internal returns (uint256 claimableAmount) {
        // Process the specific period
        VestingPeriod storage period = schedule.periods[periodIndex];
        claimableAmount = _getClaimableAmountForPeriod(period);

        // Update claimed amount
        if (claimableAmount > 0) {
            period.claimedAmount += claimableAmount;
            // Emit event
            emit TokenRelease(_msgSender(), schedule.beneficiary, scheduleId, periodIndex, claimableAmount);
        }
    }

    /**
     * @notice Calculates the vested amount for a specific period
     * @dev Implements linear vesting with optional cliff period
     *
     * @param period The vesting period to calculate for
     * @return vestedAmount The amount vested up to the current time
     */
    function _getVestedAmountForPeriod(VestingPeriod memory period) internal view returns (uint256 vestedAmount) {
        uint256 currentTime = block.timestamp;
        uint256 vestingStartTime;
        uint256 vestingEndTime;

        // Calculate actual start and end times based on vesting mode
        if (globalVestingMode) {
            // In global mode, check if global vesting has started
            if (!globalVestingStarted) {
                return 0;
            }
            vestingStartTime = globalVestingStartTime + period.startPeriod;
            vestingEndTime = globalVestingStartTime + period.endPeriod;
        } else {
            // In individual mode, use absolute timestamps
            vestingStartTime = period.startPeriod;
            vestingEndTime = period.endPeriod;
        }

        // If we haven't reached the start time, nothing is vested
        if (currentTime < vestingStartTime) {
            return 0;
        }

        // Calculate cliff end time if applicable
        uint256 cliffEndTime = vestingStartTime + period.cliff;

        // If we're before the cliff end, nothing is vested
        if (period.cliff > 0 && currentTime < cliffEndTime) {
            return 0;
        }
        // If we've passed the end time, everything is vested
        if (currentTime >= vestingEndTime) {
            return period.amount;
        }

        uint256 elapsedTime = currentTime - vestingStartTime;
        uint256 vestingDuration = vestingEndTime - vestingStartTime;
        // Can only reach here if currentTime >= vestingStartTime && currentTime < vestingEndTime
        // Therefore, vestingDuration > 0

        // Calculate vested amount using proportion of time elapsed (linear vesting)
        vestedAmount = (period.amount * elapsedTime) / vestingDuration;
    }

    /**
     * @notice Calculates the claimable amount for a specific period
     * @dev Returns vested amount minus already claimed amount
     *
     * Note that this function does not check if the schedule is cancelled.
     *
     * @param period The vesting period to calculate for
     * @return claimableAmount The amount that can be claimed
     */
    function _getClaimableAmountForPeriod(VestingPeriod memory period) internal view returns (uint256 claimableAmount) {
        // Skip if already fully claimed
        if (period.claimedAmount == period.amount) {
            return 0;
        }
        uint256 vestedAmount = _getVestedAmountForPeriod(period);

        // Claimable is vested minus already claimed
        if (vestedAmount > period.claimedAmount) {
            claimableAmount = vestedAmount - period.claimedAmount;
        } else {
            claimableAmount = 0;
        }
    }

    /**
     * @notice Calculates the total claimable amount for a schedule
     * @dev Sums claimable amounts across all periods if schedule is not cancelled
     *
     * @param schedule The schedule to calculate for
     * @return totalClaimable The total claimable amount
     */
    function _getClaimableAmountForSchedule(Schedule memory schedule) internal view returns (uint256 totalClaimable) {
        // If schedule is cancelled, nothing is claimable
        if (schedule.isCancelled) {
            return 0;
        }
        // Sum claimable amounts across all periods
        for (uint256 i = 0; i < schedule.periods.length; ) {
            totalClaimable += _getClaimableAmountForPeriod(schedule.periods[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Internal function to process token release to a beneficiary or admin
     * @dev Transfers tokens and emits events
     *
     * This function performs an external call, and so it should only be called after all checks and effects
     * have been performed.
     *
     * @param recipient The token recipient address
     * @param amount The amount to release
     */
    function _processTokenRelease(address recipient, uint256 amount) internal {
        // Update committed tokens by decreasing the released amount
        committedTokens -= amount;

        // Transfer tokens
        vestingToken.safeTransfer(recipient, amount);
    }
}
