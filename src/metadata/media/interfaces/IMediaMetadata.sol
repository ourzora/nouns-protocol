// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { MediaMetadataTypesV1 } from "../types/MediaMetadataTypesV1.sol";
import { IBaseMetadata } from "../../interfaces/IBaseMetadata.sol";

/// @title IMediaMetadataRenderer
/// @author Neokry
/// @notice The external Metadata Renderer events, errors, and functions
interface IMediaMetadata is IBaseMetadata, MediaMetadataTypesV1 {
    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    /// @notice Additional token properties have been set
    event AdditionalTokenPropertiesSet(AdditionalTokenProperty[] _additionalJsonProperties);

    /// @notice Emitted when the contract image is updated
    event ContractImageUpdated(string prevImage, string newImage);

    /// @notice Emitted when the collection description is updated
    event DescriptionUpdated(string prevDescription, string newDescription);

    /// @notice Emitted when the collection uri is updated
    event WebsiteURIUpdated(string lastURI, string newURI);

    ///                                                          ///
    ///                            ERRORS                        ///
    ///                                                          ///

    /// @dev Reverts if the caller isn't the token contract
    error ONLY_TOKEN();

    /// @dev Reverts if the caller does not include a media item during an artwork upload
    error ONE_MEDIA_ITEM_REQUIRED();

    /// @dev Reverts if the selection type is invalid
    error INVALID_SELECTION_TYPE();

    ///                                                          ///
    ///                           FUNCTIONS                      ///
    ///                                                          ///

    /// @notice The contract image
    function contractImage() external view returns (string memory);

    /// @notice The collection description
    function description() external view returns (string memory);

    /// @notice Updates the contract image
    /// @param newContractImage The new contract image
    function updateContractImage(string memory newContractImage) external;

    /// @notice Updates the collection description
    /// @param newDescription The new description
    function updateDescription(string memory newDescription) external;
}
