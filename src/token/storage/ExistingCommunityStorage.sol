// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { TokenTypesV1 } from "../types/TokenTypesV1.sol";

/// @title TokenStorageV1
/// @author Rohan Kulkarni
/// @notice The Token storage contract
contract ExistingCommunityStorage is TokenTypesV1 {
    /// @notice The token settings
    Settings internal settings;

    /// @notice The vesting details of a founder
    /// @dev Founder id => Founder
    mapping(uint256 => Founder) internal founder;

    /// @notice The recipient of a token
    /// @dev ERC-721 token id => Founder
    mapping(uint256 => Founder) internal tokenRecipient;

    mapping(uint256 => bool) internal claimed;

    bytes32 public merkleRoot;

    uint256 public auctionOffset;

    bool public isClaimOpen;
}
