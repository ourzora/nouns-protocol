// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { ManagerTypesV1 } from "../types/ManagerTypesV1.sol";

/// @notice Manager Storage V1
/// @author Rohan Kulkarni
/// @notice The Manager storage contract
contract ManagerStorageV1 is ManagerTypesV1 {
    /// @notice If a contract has been registered as an upgrade
    /// @dev Base impl => Upgrade impl
    mapping(address => mapping(address => bool)) internal isUpgrade;

    /// @notice Registers deployed addresses
    /// @dev Token deployed address => Struct of all other DAO addresses
    mapping(address => DAOAddresses) internal daoAddressesByToken;
}
