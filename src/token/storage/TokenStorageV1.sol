// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { TokenTypesV1 } from "../types/TokenTypesV1.sol";

/// @title TokenStorageV1
/// @author Rohan Kulkarni
/// @notice The Token storage contract
contract TokenStorageV1 is TokenTypesV1 {
    /// @notice The token settings
    Settings internal settings;

    mapping(uint256 => Founder) public founder;

    mapping(uint256 => Founder) internal tokenRecipient;
}
