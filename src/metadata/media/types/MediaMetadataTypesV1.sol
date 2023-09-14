// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title MediaMetadataTypesV1
/// @author Neokry
/// @notice The Metadata Renderer custom data types
interface MediaMetadataTypesV1 {
    struct MediaItem {
        /// @notice The image content URI
        string imageURI;
        /// @notice The animation content URI
        string animationURI;
    }

    struct Settings {
        /// @notice The token address
        address token;
        /// @notice The project URI
        string projectURI;
        ///  @notice The project description
        string description;
        ///  @notice The token contract image
        string contractImage;
    }

    struct AdditionalTokenProperty {
        string key;
        string value;
        bool quote;
    }
}
