// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { MediaMetadataTypesV1 } from "../types/MediaMetadataTypesV1.sol";

/// @title MediaMetadataStorageV1
/// @author Neokry
/// @notice The Metadata Renderer storage contract
contract MediaMetadataStorageV1 is MediaMetadataTypesV1 {
    /// @notice The metadata renderer settings
    Settings public settings;

    /// @notice The media items chosen from upon generation
    MediaItem[] public mediaItems;

    /// @notice Additional JSON key/value properties for each token.
    /// @dev While strings are quoted, JSON needs to be escaped.
    AdditionalTokenProperty[] internal additionalTokenProperties;
}
