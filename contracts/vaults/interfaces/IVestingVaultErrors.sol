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
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/draft-IERC6093.sol)
pragma solidity 0.8.29;

/**
 * @dev Vesting Vault contract specific errors.
 * @custom:security-contact support@fireblocks.com
 */
interface IVestingVaultErrors {
    /**
     * @dev Indicates that the vesting schedule is already cancelled.
     * @param scheduleId The ID of the cancelled schedule.
     */
    error CancelledSchedule(uint256 scheduleId);

    /**
     * @dev Indicates that the global vesting date has already been set.
     */
    error GlobalVestingAlreadyStarted();

    /**
     * @dev Indicates that global vesting date hasn't been set.
     */
    error GlobalVestingNotStarted();

    /**
     * @dev Indicates that the global vesting mode is not enabled.
     */
    error GlobalVestingNotEnabled();

    /**
     * @dev Indicates an error related to the current virtual `balance` of the contract. Used to ensure schedules
     *      are fully backed by the contract's balance.
     * @param balance Current balance for the vesting vault.
     * @param available Maximum amount available to be committed to new vesting schedules.
     */
    error InsufficientBalance(uint256 balance, uint256 available);

    /**
     * @dev Indicates that the vesting start time is invalid.
     * @param periodIndex The index of the vesting period that has an invalid start time.
     * @param startTime The invalid start time that was provided.
     */
    error InvalidStartTime(uint256 periodIndex, uint256 startTime);

    /**
     * @dev Indicates that the vesting end time is invalid.
     * @param periodIndex The index of the vesting period that has an invalid end time.
     * @param endTime The invalid end time that was provided.
     */
    error InvalidEndTime(uint256 periodIndex, uint256 endTime);

    /**
     * @dev Indicates that the cliff is invalid.
     * @param periodIndex The index of the vesting period that has an invalid cliff.
     * @param cliff The invalid cliff that was provided.
     */
    error InvalidCliff(uint256 periodIndex, uint256 cliff);

    /**
     * @dev Indicates that the vesting duration (endPeriod - startPeriod) is invalid.
     * @param periodIndex The index of the vesting period that has an invalid duration.
     * @param duration The invalid duration that was provided.
     */
    error InvalidDuration(uint256 periodIndex, uint256 duration);

    /**
     * @dev Indicates that the vesting schedule period with the given index is not valid.
     * @param scheduleId The ID of the vesting schedule.
     * @param periodIndex The invalid vesting period index.
     */
    error InvalidVestingPeriodIndex(uint256 scheduleId, uint256 periodIndex);

    /**
     * @dev Indicates that the vesting schedule cannot be cancelled.
     * @param scheduleId The ID of the schedule that cannot be cancelled.
     */
    error IrrevocableSchedule(uint256 scheduleId);

    /**
     * @dev Indicates that there are not available tokens to claim.
     */
    error NoTokensToClaim();
}
