// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {GovernorTypesV1} from "../types/GovernorTypesV1.sol";

contract GovernorStorageV1 is GovernorTypesV1 {
    /// @notice The DAO governor settings
    Settings internal settings;

    /// @dev Proposal Id => Proposal
    mapping(uint256 => Proposal) public proposals;

    /// @dev Proposal Id => User => Has Voted
    mapping(uint256 => mapping(address => bool)) internal hasVoted;
}
