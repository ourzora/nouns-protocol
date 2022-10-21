// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { IOwnable } from "../../lib/utils/Ownable.sol";
import { IUUPS } from "../../lib/interfaces/IUUPS.sol";

/// @title ITreasury
/// @author Rohan Kulkarni
/// @notice The external Treasury events, errors and functions
interface ITreasury is IUUPS, IOwnable {
    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    /// @notice Emitted when a transaction is scheduled
    event TransactionScheduled(bytes32 proposalId, uint256 timestamp);

    /// @notice Emitted when a transaction is canceled
    event TransactionCanceled(bytes32 proposalId);

    /// @notice Emitted when a transaction is executed
    event TransactionExecuted(bytes32 proposalId, address[] targets, uint256[] values, bytes[] payloads);

    /// @notice Emitted when the transaction delay is updated
    event DelayUpdated(uint256 prevDelay, uint256 newDelay);

    /// @notice Emitted when the grace period is updated
    event GracePeriodUpdated(uint256 prevGracePeriod, uint256 newGracePeriod);

    ///                                                          ///
    ///                            ERRORS                        ///
    ///                                                          ///

    /// @dev Reverts if tx was already queued
    error PROPOSAL_ALREADY_QUEUED();

    /// @dev Reverts if tx was not queued
    error PROPOSAL_NOT_QUEUED();

    /// @dev Reverts if a tx isn't ready to execute
    /// @param proposalId The proposal id
    error EXECUTION_NOT_READY(bytes32 proposalId);

    /// @dev Reverts if a tx failed
    /// @param txIndex The index of the tx
    error EXECUTION_FAILED(uint256 txIndex);

    /// @dev Reverts if execution was attempted after the grace period
    error EXECUTION_EXPIRED();

    /// @dev Reverts if the caller was not the treasury itself
    error ONLY_TREASURY();

    /// @dev Reverts if the caller was not the contract manager
    error ONLY_MANAGER();

    ///                                                          ///
    ///                          FUNCTIONS                       ///
    ///                                                          ///

    /// @notice Initializes a DAO's treasury
    /// @param governor The governor address
    /// @param timelockDelay The time delay to execute a queued transaction
    function initialize(address governor, uint256 timelockDelay) external;

    /// @notice The timestamp that a proposal is valid to execute
    /// @param proposalId The proposal id
    function timestamp(bytes32 proposalId) external view returns (uint256);

    /// @notice If a proposal has been queued
    /// @param proposalId The proposal ids
    function isQueued(bytes32 proposalId) external view returns (bool);

    /// @notice If a proposal is ready to execute (does not consider if a proposal has expired)
    /// @param proposalId The proposal id
    function isReady(bytes32 proposalId) external view returns (bool);

    /// @notice If a proposal has expired to execute
    /// @param proposalId The proposal id
    function isExpired(bytes32 proposalId) external view returns (bool);

    /// @notice Schedules a proposal for execution
    /// @param proposalId The proposal id
    function queue(bytes32 proposalId) external returns (uint256 eta);

    /// @notice Removes a queued proposal
    /// @param proposalId The proposal id
    function cancel(bytes32 proposalId) external;

    /// @notice Executes a queued proposal
    /// @param targets The target addresses to call
    /// @param values The ETH values of each call
    /// @param calldatas The calldata of each call
    /// @param descriptionHash The hash of the description
    /// @param proposer The proposal creator
    function execute(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        bytes32 descriptionHash,
        address proposer
    ) external payable;

    /// @notice The time delay to execute a queued transaction
    function delay() external view returns (uint256);

    /// @notice The time period to execute a transaction
    function gracePeriod() external view returns (uint256);

    /// @notice Updates the time delay
    /// @param newDelay The new time delay
    function updateDelay(uint256 newDelay) external;

    /// @notice Updates the grace period
    /// @param newGracePeriod The grace period
    function updateGracePeriod(uint256 newGracePeriod) external;
}
