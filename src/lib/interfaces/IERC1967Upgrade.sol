// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title IERC1967Upgrade
/// @author Rohan Kulkarni
/// @notice The external ERC1967Upgrade events and errors
interface IERC1967Upgrade {
    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    /// @notice Emitted when the implementation is upgraded
    /// @param impl The address of the implementation
    event Upgraded(address impl);

    ///                                                          ///
    ///                            ERRORS                        ///
    ///                                                          ///

    /// @dev Reverts if an implementation is an invalid upgrade
    /// @param impl The address of the invalid implementation
    error INVALID_UPGRADE(address impl);

    /// @dev Reverts if an implementation upgrade is not stored at the storage slot of the original
    error UNSUPPORTED_UUID();

    /// @dev Reverts if an implementation does not support ERC1822 proxiableUUID()
    error ONLY_UUPS();
}
