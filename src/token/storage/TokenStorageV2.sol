// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { TokenTypesV2 } from "../types/TokenTypesV2.sol";

/// @title TokenStorageV2
/// @author James Geary
/// @notice The Token storage contract
contract TokenStorageV2 is TokenTypesV2 {
    /// @notice The minter status of an address
    mapping(address => bool) public minter;
}
