// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { GovernorTypesV1 } from "../types/GovernorTypesV1.sol";

/// @title GovernorStorageV1
/// @author Rohan Kulkarni
/// @notice The Governor storage contract
contract GovernorStorageV1 is GovernorTypesV1 {
    /// @notice The governor settings
    Settings internal settings;

    /// @notice The details of a proposal
    /// @dev Proposal Id => Proposal
    mapping(bytes32 => Proposal) internal proposals;

    /// @notice If a user has voted on a proposal
    /// @dev Proposal Id => User => Has Voted
    mapping(bytes32 => mapping(address => bool)) internal hasVoted;
}
