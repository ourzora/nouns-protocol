// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title IPausable
/// @author Rohan Kulkarni
/// @notice The external Pausable events, errors, and functions
interface IPausable {
    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    /// @notice Emitted when the contract is paused
    /// @param user The address that paused the contract
    event Paused(address user);

    /// @notice Emitted when the contract is unpaused
    /// @param user The address that unpaused the contract
    event Unpaused(address user);

    ///                                                          ///
    ///                            ERRORS                        ///
    ///                                                          ///

    /// @dev Reverts if called when the contract is paused
    error PAUSED();

    /// @dev Reverts if called when the contract is unpaused
    error UNPAUSED();

    ///                                                          ///
    ///                           FUNCTIONS                      ///
    ///                                                          ///

    /// @notice If the contract is paused
    function paused() external view returns (bool);
}
