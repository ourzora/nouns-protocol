// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { MetadataRendererTypesV1 } from "../types/MetadataRendererTypesV1.sol";

/// @title MetadataRendererTypesV1
/// @author Iain Nash & Rohan Kulkarni
/// @notice The Metadata Renderer storage contract
contract MetadataRendererStorageV1 is MetadataRendererTypesV1 {
    /// @notice The metadata renderer settings
    Settings public settings;

    /// @notice The properties chosen from upon generation
    Property[] public properties;

    /// @notice The IPFS data of all property items
    IPFSGroup[] public ipfsData;

    /// @notice The attributes generated for a token - mapping of tokenID uint16 array
    /// @dev Array of size 16 1st element [0] used for number of attributes chosen, next N elements for those selections
    /// @dev token ID
    mapping(uint256 => uint16[16]) public attributes;
}
