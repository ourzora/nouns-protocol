// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/// @notice TreasuryTypesV1
/// @author Rohan Kulkarni
/// @notice The treasury's custom data types
contract TreasuryTypesV1 {
    /// @notice The settings type
    /// @param gracePeriod The amount of time to execute a proposal
    /// @param delay The amount of time a queued proposal is delayed until execution
    struct Settings {
        uint128 gracePeriod;
        uint128 delay;
    }
}
