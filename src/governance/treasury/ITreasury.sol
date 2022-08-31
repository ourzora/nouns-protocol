// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

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

    function initialize(address governor, uint256 delay) external;

    function timestamp(bytes32 proposalId) external view returns (uint256);

    function isQueued(bytes32 proposalId) external view returns (bool);

    function isReady(bytes32 proposalId) external view returns (bool);

    function isExpired(bytes32 proposalId) external view returns (bool);

    function hashProposal(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        bytes32 descriptionHash
    ) external pure returns (bytes32);

    function schedule(bytes32 proposalId) external returns (uint256 eta);

    function cancel(bytes32 proposalId) external;

    function execute(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        bytes32 _descriptionHash
    ) external payable;

    function delay() external view returns (uint256);

    function gracePeriod() external view returns (uint256);

    function updateDelay(uint256 newDelay) external;

    function updateGracePeriod(uint256 newGracePeriod) external;
}
