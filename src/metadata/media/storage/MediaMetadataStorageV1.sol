// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { MediaMetadataTypesV1 } from "../types/MediaMetadataTypesV1.sol";

/// @title MediaMetadataTypesV1
/// @author Neokry
/// @notice The Metadata Renderer storage contract
contract MediaMetadataStorageV1 is MediaMetadataTypesV1 {
    /// @notice The metadata renderer settings
    Settings public settings;

    /// @notice The media items chosen from upon generation
    MediaItem[] public mediaItems;

    /// @notice The attributes generated for a token - mapping of tokenID uint16 array
    /// @dev Array of size 16 1st element [0] used for number of attributes chosen, next N elements for those selections
    /// @dev token ID
    mapping(uint256 => uint256) public tokenIdToSelectedMediaItem;

    /// @notice Additional JSON key/value properties for each token.
    /// @dev While strings are quoted, JSON needs to be escaped.
    AdditionalTokenProperty[] internal additionalTokenProperties;
}
