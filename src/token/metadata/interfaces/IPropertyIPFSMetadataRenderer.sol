// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { MetadataRendererTypesV1 } from "../types/MetadataRendererTypesV1.sol";
import { IBaseMetadata } from "./IBaseMetadata.sol";

/// @title IPropertyIPFSMetadataRenderer
/// @author Iain Nash & Rohan Kulkarni
/// @notice The external PropertyIPFSMetadataRenderer
interface IPropertyIPFSMetadataRenderer is IBaseMetadata, MetadataRendererTypesV1 {
    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    /// @notice Emitted when a property is added
    event PropertyAdded(uint256 id, string name);

    /// @notice Emitted when an item is added
    event ItemAdded(uint256 propertyId, uint256 index);

    /// @notice Emitted when the contract image is updated
    event ContractImageUpdated(string prevImage, string newImage);

    /// @notice Emitted when the renderer base is updated
    event RendererBaseUpdated(string prevRendererBase, string newRendererBase);

    /// @notice Emitted when the collection description is updated
    event DescriptionUpdated(string prevDescription, string newDescription);

    ///                                                          ///
    ///                            ERRORS                        ///
    ///                                                          ///

    /// @dev
    error ONLY_TOKEN();

    /// @dev
    error TOKEN_NOT_MINTED(uint256 tokenId);

    ///                                                          ///
    ///                           FUNCTIONS                      ///
    ///                                                          ///

    function addProperties(
        string[] calldata names,
        ItemParam[] calldata items,
        IPFSGroup calldata ipfsGroup
    ) external;

    function propertiesCount() external view returns (uint256);

    function itemsCount(uint256 propertyId) external view returns (uint256);

    function getAttributes(uint256 tokenId) external view returns (bytes memory aryAttributes, bytes memory queryString);

    function contractImage() external view returns (string memory);

    function rendererBase() external view returns (string memory);

    function description() external view returns (string memory);

    function updateContractImage(string memory newContractImage) external;

    function updateRendererBase(string memory newRendererBase) external;
}
