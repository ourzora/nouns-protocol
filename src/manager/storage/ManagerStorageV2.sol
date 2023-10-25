// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { ManagerTypesV2 } from "../types/ManagerTypesV2.sol";

/// @notice Manager Storage V2
/// @author Neokry
/// @notice The Manager storage contract
contract ManagerStorageV2 is ManagerTypesV2 {
    /// @notice The protocol rewards configuration
    RewardConfig rewards;
}
