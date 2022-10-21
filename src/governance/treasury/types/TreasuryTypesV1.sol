// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @notice TreasuryTypesV1
/// @author Rohan Kulkarni
/// @notice The treasury's custom data types
contract TreasuryTypesV1 {
    /// @notice The settings type
    /// @param gracePeriod The time period to execute a proposal
    /// @param delay The time delay to execute a queued transaction
    struct Settings {
        uint128 gracePeriod;
        uint128 delay;
    }
}
