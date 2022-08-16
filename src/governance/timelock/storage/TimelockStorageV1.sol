// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

/// @notice TimelockStorageV1
/// @author Rohan Kulkarni
/// @notice
contract TimelockStorageV1 {
    /// @notice The time between a queued transaction and its execution
    uint256 public delay;

    /// @notice The timestamp that a proposal is ready for execution.
    ///         Executed proposals are stored as 1 second.
    /// @dev Proposal Id => Timestamp
    mapping(uint256 => uint256) public timestamps;
}
