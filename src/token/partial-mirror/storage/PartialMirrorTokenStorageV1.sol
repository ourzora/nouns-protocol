// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { PartialMirrorTokenTypesV1 } from "../types/PartialMirrorTokenTypesV1.sol";
import { BitMaps } from "@openzeppelin/contracts/utils/structs/BitMaps.sol";

/// @title PartialMirrorTokenStorageV1
/// @author Neokry
/// @notice The Token storage contract
contract PartialMirrorTokenStorageV1 is PartialMirrorTokenTypesV1 {
    /// @notice The token settings
    Settings internal settings;

    /// @notice The vesting details of a founder
    /// @dev Founder id => Founder
    mapping(uint256 => Founder) internal founder;

    /// @notice The recipient of a token
    /// @dev ERC-721 token id => Founder
    mapping(uint256 => Founder) internal tokenRecipient;

    /// @notice The minter status of an address
    mapping(address => bool) public minter;

    /// @notice Marks the first n tokens as reserved
    uint256 public reservedUntilTokenId;

    /// @notice The token to mirror
    address mirroredToken;
}
