// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { PropertyMetadataTypesV1 } from "../types/PropertyMetadataTypesV1.sol";
import { PropertyMetadataTypesV2 } from "../types/PropertyMetadataTypesV2.sol";
import { IBaseMetadata } from "../../interfaces/IBaseMetadata.sol";

/// @title IPropertyMetadata
/// @author Iain Nash & Rohan Kulkarni
/// @notice The external Metadata Renderer events, errors, and functions
interface IPropertyMetadata is IBaseMetadata, PropertyMetadataTypesV1, PropertyMetadataTypesV2 {
    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    /// @notice Emitted when a property is added
    event PropertyAdded(uint256 id, string name);

    /// @notice Additional token properties have been set
    event AdditionalTokenPropertiesSet(AdditionalTokenProperty[] _additionalJsonProperties);

    /// @notice Emitted when the contract image is updated
    event ContractImageUpdated(string prevImage, string newImage);

    /// @notice Emitted when the renderer base is updated
    event RendererBaseUpdated(string prevRendererBase, string newRendererBase);

    /// @notice Emitted when the collection description is updated
    event DescriptionUpdated(string prevDescription, string newDescription);

    /// @notice Emitted when the collection uri is updated
    event WebsiteURIUpdated(string lastURI, string newURI);

    ///                                                          ///
    ///                            ERRORS                        ///
    ///                                                          ///

    /// @dev Reverts if the caller isn't the token contract
    error ONLY_TOKEN();

    /// @dev Reverts if querying attributes for a token not minted
    error TOKEN_NOT_MINTED(uint256 tokenId);

    /// @dev Reverts if the founder does not include both a property and item during the initial artwork upload
    error ONE_PROPERTY_AND_ITEM_REQUIRED();

    /// @dev Reverts if an item is added for a non-existent property
    error INVALID_PROPERTY_SELECTED(uint256 selectedPropertyId);

    ///
    error TOO_MANY_PROPERTIES();

    ///                                                          ///
    ///                           STRUCTS                        ///
    ///                                                          ///

    struct PropertyMetadataParams {
        /// @notice The collection description
        string description;
        /// @notice The contract image
        string contractImage;
        /// @notice The project URI
        string projectURI;
        /// @notice The renderer base
        string rendererBase;
    }

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
    function getAttributes(uint256 tokenId) external view returns (string memory resultAttributes, string memory queryString);

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
