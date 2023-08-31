// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @notice Manager Storage V2
/// @author Neokry
/// @notice The Manager storage contract
contract ManagerStorageV2 {
    /// @notice Determine if a contract is a registered implementation
    /// @dev Implementation type => Implementation address => Registered
    mapping(uint8 => mapping(address => bool)) internal isImplementation;
}
