// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title TokenStorageV3
/// @author Neokry
/// @notice The Token storage contract
contract TokenStorageV3 {
    /// @notice Marks the first n tokens as reserved
    uint256 public reservedUntilTokenId;
}
