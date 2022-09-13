// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title InitializableStorageV1
/// @author Rohan Kulkarni
/// @notice The storage for Initializable
contract InitializableStorageV1 {
    /// @dev Indicates the contract has been initialized
    uint8 internal _initialized;

    /// @dev Indicates the contract is being initialized
    bool internal _initializing;
}
