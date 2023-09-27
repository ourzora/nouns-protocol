// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { MediaMetadataTypesV1 } from "../types/MediaMetadataTypesV1.sol";
import { IBaseMetadata } from "../../interfaces/IBaseMetadata.sol";

/// @title IMediaMetadata
/// @author Neokry
/// @notice The external Metadata Renderer events, errors, and functions
interface IMediaMetadata is IBaseMetadata, MediaMetadataTypesV1 {
    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    /// @notice Additional token properties have been set
    event AdditionalTokenPropertiesSet(AdditionalTokenProperty[] _additionalJsonProperties);

    ///                                                          ///
    ///                            ERRORS                        ///
    ///                                                          ///

    /// @dev Reverts if the caller isn't the token contract
    error ONLY_TOKEN();

    /// @dev Reverts if the caller does not include a media item during an artwork upload
    error ONE_MEDIA_ITEM_REQUIRED();

    ///                                                          ///
    ///                           STRUCTS                        ///
    ///                                                          ///

    struct MediaMetadataParams {
        /// @notice The collection description
        string description;
        /// @notice The contract image
        string contractImage;
        /// @notice The project URI
        string projectURI;
    }
}
