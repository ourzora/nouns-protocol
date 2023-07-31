// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title MediaMetadataTypesV1
/// @author Neokry
/// @notice The Metadata Renderer custom data types
interface MediaMetadataTypesV1 {
    struct MediaItem {
        string imageURI;
        string animationURI;
    }

    struct Settings {
        address token;
        string projectURI;
        string description;
        string contractImage;
        string rendererBase;
    }

    struct AdditionalTokenProperty {
        string key;
        string value;
        bool quote;
    }
}
