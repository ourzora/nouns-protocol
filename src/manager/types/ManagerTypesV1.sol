// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title ManagerTypesV1
/// @author Iain Nash & Rohan Kulkarni
/// @notice The external Base Metadata errors and functions
interface ManagerTypesV1 {
  /// @notice Stores deployed addresses for a given token's DAO
  struct DAOAddresses {
    /// @notice Address for deployed metadata contract
    address metadata;
    /// @notice Address for deployed auction contract
    address auction;
    /// @notice Address for deployed treasury contract
    address treasury;
    /// @notice Address for deployed governor contract
    address governor;
  }
}