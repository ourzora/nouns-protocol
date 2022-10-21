// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { TreasuryTypesV1 } from "../types/TreasuryTypesV1.sol";

/// @notice TreasuryStorageV1
/// @author Rohan Kulkarni
/// @notice The Treasury storage contract
contract TreasuryStorageV1 is TreasuryTypesV1 {
    /// @notice The treasury settings
    Settings internal settings;

    /// @notice The timestamp that a queued proposal is ready to execute
    /// @dev Proposal Id => Timestamp
    mapping(bytes32 => uint256) internal timestamps;
}
