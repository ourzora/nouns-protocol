// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title TokenTypesV2
/// @author James Geary
/// @notice The Token custom data types
interface TokenTypesV2 {
    struct MinterParams {
        address minter;
        bool allowed;
    }
}
