// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { MetadataRendererTypesV1 } from "../types/MetadataRendererTypesV1.sol";
import { IBaseMetadata } from "./IBaseMetadata.sol";

/// @title IPropertyIPFSMetadataRenderer
/// @author Iain Nash & Rohan Kulkarni
/// @notice The external Metadata Renderer events, errors, and functions
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

    /// @dev Reverts if the caller isn't the token contract
    error ONLY_TOKEN();

    /// @dev Reverts if querying attributes for a token not minted
    error TOKEN_NOT_MINTED(uint256 tokenId);

    ///                                                          ///
    ///                           FUNCTIONS                      ///
    ///                                                          ///

    /// @notice Adds properties and/or items to be pseudo-randomly chosen from during token minting
    /// @param names The names of the properties to add
    /// @param items The items to add to each property
    /// @param ipfsGroup The IPFS base URI and extension
    function addProperties(
        string[] calldata names,
        ItemParam[] calldata items,
        IPFSGroup calldata ipfsGroup
    ) external;

    /// @notice The number of properties
    function propertiesCount() external view returns (uint256);

    /// @notice The number of items in a property
    /// @param propertyId The property id
    function itemsCount(uint256 propertyId) external view returns (uint256);

    /// @notice The properties and query string for a generated token
    /// @param tokenId The ERC-721 token id
    function getAttributes(uint256 tokenId) external view returns (bytes memory aryAttributes, bytes memory queryString);

    /// @notice The contract image
    function contractImage() external view returns (string memory);

    /// @notice The renderer base
    function rendererBase() external view returns (string memory);

    /// @notice The collection description
    function description() external view returns (string memory);

    /// @notice Updates the contract image
    /// @param newContractImage The new contract image
    function updateContractImage(string memory newContractImage) external;

    /// @notice Updates the renderer base
    /// @param newRendererBase The new renderer base
    function updateRendererBase(string memory newRendererBase) external;

    /// @notice Updates the collection description
    /// @param newDescription The new description
    function updateDescription(string memory newDescription) external;
}
