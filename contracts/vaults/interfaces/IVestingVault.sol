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

/**
 * @title IVestingVault
 * @author Fireblocks
 * @notice Interface for the VestingVault contract that manages token vesting schedules
 * @custom:security-contact support@fireblocks.com
 */
interface IVestingVault {
    /// Type declarations

    /**
     * @notice Represents a vesting period within a schedule
     * @param startPeriod The start time of this vesting period
     * @param endPeriod The end time of this vesting period
     * @param cliff The cliff period for this vesting period
     * @param amount The total amount of tokens in this vesting period (must be greater than zero)
     * @param claimedAmount The amount of tokens already claimed from this period
     */
    struct VestingPeriod {
        uint64 startPeriod;
        uint64 endPeriod;
        uint64 cliff;
        uint256 amount;
        uint256 claimedAmount;
    }

    /**
     * @notice Represents vesting period parameters for schedule creation
     * @dev This is the DTO for VestingPeriod, used for creating new schedules. It does not include the `claimedAmount`
     *      property, which is only relevant after the schedule is created.
     * @param startPeriod The start time of this vesting period
     * @param endPeriod The end time of this vesting period
     * @param cliff The cliff period for this vesting period
     * @param amount The total amount of tokens in this vesting period (must be greater than zero)
     */
    struct VestingPeriodParam {
        uint64 startPeriod;
        uint64 endPeriod;
        uint64 cliff;
        uint256 amount;
    }

    /**
     * @notice Represents a complete vesting schedule for a beneficiary
     * @param id Global unique identifier for this schedule
     * @param beneficiary The recipient of vested tokens from this schedule
     * @param isCancellable Whether this schedule can be cancelled by admins
     * @param isCancelled Whether this schedule has been cancelled
     * @param periods Array of vesting periods that comprise this schedule
     */
    struct Schedule {
        uint32 id;
        address beneficiary;
        bool isCancellable;
        bool isCancelled;
        VestingPeriod[] periods;
    }

    /// Events

    /**
     * @notice Emitted when a new vesting schedule is created
     * @param caller The address that created the schedule
     * @param beneficiary The beneficiary of the vesting schedule
     * @param scheduleId The ID of the created schedule
     * @param schedule The created schedule details
     */
    event VestingScheduleCreated(
        address indexed caller,
        address indexed beneficiary,
        uint256 indexed scheduleId,
        Schedule schedule
    );

    /**
     * @notice Emitted when global vesting is started
     * @param timestamp The timestamp when global vesting started
     */
    event GlobalVestingStarted(uint256 timestamp);

    /**
     * @notice Emitted when tokens are released (claimed or admin-released)
     * @param caller The address that invoked the release (beneficiary for claim, admin for release)
     * @param beneficiary The beneficiary who received the tokens
     * @param scheduleId The schedule ID from which tokens were released
     * @param periodIndex The period index from which tokens were released
     * @param amount The amount of tokens released
     */
    event TokenRelease(
        address indexed caller,
        address indexed beneficiary,
        uint256 indexed scheduleId,
        uint256 periodIndex,
        uint256 amount
    );

    /**
     * @notice Emitted when a vesting schedule is cancelled
     * @param admin The admin who cancelled the schedule
     * @param beneficiary The beneficiary whose schedule was cancelled
     * @param scheduleId The ID of the cancelled schedule
     * @param claimedAmount The amount transferred to beneficiary during cancellation
     * @param reclaimedAmount The amount of unvested tokens transferred to the admin
     */
    event VestingScheduleCancelled(
        address indexed admin,
        address indexed beneficiary,
        uint256 indexed scheduleId,
        uint256 claimedAmount,
        uint256 reclaimedAmount
    );

    /// Functions

    /**
     * @notice Creates a vesting schedule for a beneficiary
     * @param beneficiary Address of the beneficiary
     * @param isCancellable Whether this schedule can be cancelled by admins
     * @param periods Array of vesting periods for the schedule
     * @return scheduleId The ID of the created schedule
     */
    function createSchedule(
        address beneficiary,
        bool isCancellable,
        VestingPeriodParam[] calldata periods
    ) external returns (uint32 scheduleId);

    /**
     * @notice Starts global vesting for all schedules
     */
    function startGlobalVesting() external;

    /**
     * @notice Claims all available vested tokens for the caller across all schedules
     */
    function claim() external;

    /**
     * @notice Claims available vested tokens for a specific schedule
     * @param scheduleId The ID of the schedule to claim from
     */
    function claim(uint256 scheduleId) external;

    /**
     * @notice Claims available vested tokens for a specific period within a schedule
     * @param scheduleId The ID of the schedule
     * @param periodIndex The index of the period within the schedule
     */
    function claim(uint256 scheduleId, uint256 periodIndex) external;

    /**
     * @notice Releases all available vested tokens for a beneficiary across all schedules
     * @param beneficiary The beneficiary to release tokens for
     */
    function release(address beneficiary) external;

    /**
     * @notice Releases available vested tokens for a specific schedule
     * @param scheduleId The ID of the schedule to release from
     */
    function release(uint256 scheduleId) external;

    /**
     * @notice Releases available vested tokens for a specific period within a schedule
     * @param scheduleId The ID of the schedule
     * @param periodIndex The index of the period within the schedule
     */
    function release(uint256 scheduleId, uint256 periodIndex) external;

    /**
     * @notice Cancels a vesting schedule and distributes vested tokens
     * @param scheduleId The ID of the schedule to cancel
     */
    function cancelSchedule(uint256 scheduleId) external;

    /**
     * @notice Returns all schedules for a beneficiary
     * @param beneficiary The beneficiary address
     * @return schedules Array of schedules for the beneficiary
     */
    function getSchedules(address beneficiary) external view returns (Schedule[] memory schedules);

    /**
     * @notice Returns a specific schedule by ID
     * @param scheduleId The ID of the schedule
     * @return schedule The schedule with the specified ID
     */
    function getSchedule(uint256 scheduleId) external view returns (Schedule memory schedule);

    /**
     * @notice Returns all schedule IDs for a beneficiary
     * @param beneficiary The beneficiary address
     * @return scheduleIds Array of schedule IDs for the beneficiary
     */
    function getScheduleIds(address beneficiary) external view returns (uint32[] memory scheduleIds);

    /**
     * @notice Returns the total claimable amount for a beneficiary across all schedules
     * @param beneficiary The beneficiary address
     * @return claimableAmount Total amount that can be claimed
     */
    function getClaimableAmount(address beneficiary) external view returns (uint256 claimableAmount);

    /**
     * @notice Returns the claimable amount for a specific schedule
     * @param scheduleId The ID of the schedule
     * @return claimableAmount Amount that can be claimed from the schedule
     */
    function getClaimableAmount(uint256 scheduleId) external view returns (uint256 claimableAmount);

    /**
     * @notice Returns the claimable amount for a specific period
     * @param scheduleId The ID of the schedule
     * @param periodIndex The index of the period
     * @return claimableAmount Amount that can be claimed from the period
     */
    function getClaimableAmount(
        uint256 scheduleId,
        uint256 periodIndex
    ) external view returns (uint256 claimableAmount);

    /**
     * @notice Returns the available balance for creating new vesting schedules
     * @return availableBalance The amount of tokens on the contract that can be used for new schedules
     */
    function getAvailableBalance() external view returns (uint256 availableBalance);
}
