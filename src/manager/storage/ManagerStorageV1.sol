// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @notice Manager Storage V1
/// @author Rohan Kulkarni
/// @notice The Manager storage contract
contract ManagerStorageV1 {
    /// @notice If a contract has been registered as an upgrade
    /// @dev Base impl => Upgrade impl
    mapping(address => mapping(address => bool)) internal isUpgrade;
}
