// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title IInitializable
/// @author Rohan Kulkarni
/// @notice The external Initializable events and errors
interface IInitializable {
    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    /// @notice Emitted when the contract has been initialized or reinitialized
    event Initialized(uint256 version);

    ///                                                          ///
    ///                            ERRORS                        ///
    ///                                                          ///

    /// @dev Reverts when address(0) is passed during initialization
    error ADDRESS_ZERO();

    /// @dev Reverts when attempting to disable initializers during initialization
    error INITIALIZING();

    /// @dev Reverts when calling an initialization function outside of initialization
    error NOT_INITIALIZING();

    /// @dev Reverts when attempting to reinitialize incorrectly
    error ALREADY_INITIALIZED();
}
