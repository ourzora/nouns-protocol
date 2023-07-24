// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UriEncode } from "sol-uriencode/src/UriEncode.sol";
import { MetadataBuilder } from "micro-onchain-metadata-utils/MetadataBuilder.sol";
import { MetadataJSONKeys } from "micro-onchain-metadata-utils/MetadataJSONKeys.sol";

import { UUPS } from "../../lib/proxy/UUPS.sol";
import { Initializable } from "../../lib/utils/Initializable.sol";
import { IOwnable } from "../../lib/interfaces/IOwnable.sol";
import { ERC721 } from "../../lib/token/ERC721.sol";

import { MediaMetadataStorageV1 } from "./storage/MediaMetadataStorageV1.sol";
import { IToken } from "../../token/IToken.sol";
import { IMediaMetadata } from "./interfaces/IMediaMetadata.sol";
import { IManager } from "../../manager/IManager.sol";
import { IBaseMetadata } from "../interfaces/IBaseMetadata.sol";
import { VersionedContract } from "../../VersionedContract.sol";

/// @title Media Metadata Renderer
/// @author Neokry
/// @notice A DAO's artwork generator and renderer
/// @custom:repo github.com/ourzora/nouns-protocol
contract MediaMetadata is IMediaMetadata, VersionedContract, Initializable, UUPS, MediaMetadataStorageV1 {
    ///                                                          ///
    ///                          CONSTANTS                       ///
    ///                                                          ///
    uint8 public constant SELECTION_TYPE_SEQUENTIAL = 0;

    uint8 public constant SELECTION_TYPE_RANDOM = 1;

    uint8 public constant SELECTION_TYPE_LOOP = 2;

    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IManager private immutable manager;

    ///                                                          ///
    ///                          MODIFIERS                       ///
    ///                                                          ///

    /// @notice Checks the token owner if the current action is allowed
    modifier onlyOwner() {
        if (owner() != msg.sender) {
            revert IOwnable.ONLY_OWNER();
        }

        _;
    }

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    /// @param _manager The contract upgrade manager address
    constructor(address _manager) payable initializer {
        manager = IManager(_manager);
    }

    ///                                                          ///
    ///                          INITIALIZER                     ///
    ///                                                          ///

    /// @notice Initializes a DAO's token metadata renderer
    /// @param _data The encoded metadata initialization parameters
    /// @param _token The ERC-721 token address
    function initialize(bytes calldata _data, address _token) external initializer {
        // Ensure the caller is the contract manager
        if (msg.sender != address(manager)) {
            revert ONLY_MANAGER();
        }

        // Decode the token initialization strings
        IBaseMetadata.MetadataParams memory params = abi.decode(_data, (IBaseMetadata.MetadataParams));

        // Store the renderer settings
        settings.projectURI = params.projectURI;
        settings.description = params.description;
        settings.contractImage = params.contractImage;
        settings.rendererBase = params.rendererBase;
        settings.projectURI = params.projectURI;
        settings.token = _token;
    }

    ///                                                          ///
    ///                     PROPERTIES & ITEMS                   ///
    ///                                                          ///

    /// @notice The number of items in a property
    /// @param _propertyId The property id
    /// @return items array length
    function mediaItemsCount(uint256 _propertyId) external view returns (uint256) {
        return mediaItems.length;
    }

    /// @notice Updates the additional token properties associated with the metadata.
    /// @dev Be careful to not conflict with already used keys such as "name", "description", "properties",
    function setAdditionalTokenProperties(AdditionalTokenProperty[] memory _additionalTokenProperties) external onlyOwner {
        delete additionalTokenProperties;
        for (uint256 i = 0; i < _additionalTokenProperties.length; i++) {
            additionalTokenProperties.push(_additionalTokenProperties[i]);
        }

        emit AdditionalTokenPropertiesSet(_additionalTokenProperties);
    }

    /// @notice Deletes existing properties and/or items to be pseudo-randomly chosen from during token minting, replacing them with provided properties. WARNING: This function can alter or break existing token metadata if the number of properties for this renderer change before/after the upsert. If the properties selected in any tokens do not exist in the new version those token will not render
    /// @dev We do not require the number of properties for an reset to match the existing property length, to allow multi-stage property additions (for e.g. when there are more properties than can fit in a single transaction)
    /// @param _items The items to add to each property
    function deleteAndRecreateMediaItems(MediaItem[] calldata _items) external onlyOwner {
        delete mediaItems;
        _addMediaItems(_items);
    }

    function _addMediaItems(MediaItem[] calldata _items) internal {
        // Cache the number of media items
        uint256 numStoredMediaItems = mediaItems.length;

        // Cache the number of new properties
        uint256 numNewMediaItems = _items.length;

        if (numNewMediaItems == 0) {
            revert ONE_MEDIA_ITEM_REQUIRED();
        }

        unchecked {
            for (uint256 i = 0; i < numNewMediaItems; ++i) {
                // Append storage space
                mediaItems.push();

                // Get the new media item id
                uint256 mediaItemId = numStoredMediaItems + i;

                // Store the media item
                mediaItems[mediaItemId].imageURI = _items[i].imageURI;
                mediaItems[mediaItemId].animationURI = _items[i].animationURI;
            }
        }
    }

    ///                                                          ///
    ///                     ATTRIBUTE GENERATION                 ///
    ///                                                          ///

    /// @notice Generates attributes for a token upon mint
    /// @param _tokenId The ERC-721 token id
    function onMinted(uint256 _tokenId) external override returns (bool) {
        // Ensure the caller is the token contract
        if (msg.sender != settings.token) revert ONLY_TOKEN();

        _generateMetadata(_tokenId);
    }

    /// @notice Generates attributes for a requested set of tokens
    /// @param startId The ERC-721 token id
    /// @param endId The ERC-721 token id
    function generateMetadataForTokenIds(uint256 startId, uint256 endId) external onlyOwner returns (bool[] memory results) {
        uint256 tokensLen = endId + 1 - startId;
        unchecked {
            for (uint256 i = startId; i < tokensLen; ++i) {
                results[i] = _generateMetadata(i);
            }
        }
    }

    function _generateMetadata(uint256 _tokenId) internal returns (bool) {
        // Compute some randomness for the token id
        uint256 seed = _generateSeed(_tokenId);

        // Cache the total number of properties available
        uint256 numMediaItems = mediaItems.length;
        uint8 selectionType = settings.selectionType;

        if (numMediaItems == 0 || selectionType > 2 || (selectionType == SELECTION_TYPE_SEQUENTIAL && numMediaItems - 1 < _tokenId)) {
            return false;
        }

        if (selectionType == SELECTION_TYPE_SEQUENTIAL) tokenIdToSelectedMediaItem[_tokenId] = _tokenId;
        if (selectionType == SELECTION_TYPE_RANDOM) tokenIdToSelectedMediaItem[_tokenId] = seed % numMediaItems;
        if (selectionType == SELECTION_TYPE_LOOP) tokenIdToSelectedMediaItem[_tokenId] = _tokenId % numMediaItems;

        return true;
    }

    /// @dev Generates a psuedo-random seed for a token id
    function _generateSeed(uint256 _tokenId) private view returns (uint256) {
        return uint256(keccak256(abi.encode(_tokenId, blockhash(block.number), block.coinbase, block.timestamp)));
    }

    ///                                                          ///
    ///                            URIs                          ///
    ///                                                          ///

    /// @notice Internal getter function for token name
    function _name() internal view returns (string memory) {
        return ERC721(settings.token).name();
    }

    /// @notice The contract URI
    function contractURI() external view override returns (string memory) {
        MetadataBuilder.JSONItem[] memory items = new MetadataBuilder.JSONItem[](4);

        items[0] = MetadataBuilder.JSONItem({ key: MetadataJSONKeys.keyName, value: _name(), quote: true });
        items[1] = MetadataBuilder.JSONItem({ key: MetadataJSONKeys.keyDescription, value: settings.description, quote: true });
        items[2] = MetadataBuilder.JSONItem({ key: MetadataJSONKeys.keyImage, value: settings.contractImage, quote: true });
        items[3] = MetadataBuilder.JSONItem({ key: "external_url", value: settings.projectURI, quote: true });

        return MetadataBuilder.generateEncodedJSON(items);
    }

    /// @notice The token URI
    /// @param _tokenId The ERC-721 token id
    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        MediaItem storage mediaItem = mediaItems[tokenIdToSelectedMediaItem[_tokenId]];

        MetadataBuilder.JSONItem[] memory items = new MetadataBuilder.JSONItem[](4);

        items[0] = MetadataBuilder.JSONItem({
            key: MetadataJSONKeys.keyName,
            value: string.concat(_name(), " #", Strings.toString(_tokenId)),
            quote: true
        });
        items[1] = MetadataBuilder.JSONItem({ key: MetadataJSONKeys.keyDescription, value: settings.description, quote: true });
        items[2] = MetadataBuilder.JSONItem({
            key: MetadataJSONKeys.keyImage,
            value: string.concat(settings.rendererBase, mediaItem.imageURI),
            quote: true
        });
        items[3] = MetadataBuilder.JSONItem({
            key: MetadataJSONKeys.keyAnimationURL,
            value: string.concat(settings.rendererBase, mediaItem.animationURI),
            quote: true
        });

        return MetadataBuilder.generateEncodedJSON(items);
    }

    ///                                                          ///
    ///                       METADATA SETTINGS                  ///
    ///                                                          ///

    /// @notice The associated ERC-721 token
    function token() external view returns (address) {
        return settings.token;
    }

    /// @notice The contract image
    function contractImage() external view returns (string memory) {
        return settings.contractImage;
    }

    /// @notice The renderer base
    function rendererBase() external view returns (string memory) {
        return settings.rendererBase;
    }

    /// @notice The collection description
    function description() external view returns (string memory) {
        return settings.description;
    }

    /// @notice The collection description
    function projectURI() external view returns (string memory) {
        return settings.projectURI;
    }

    /// @notice Get the owner of the metadata (here delegated to the token owner)
    function owner() public view returns (address) {
        return IOwnable(settings.token).owner();
    }

    ///                                                          ///
    ///                       UPDATE SETTINGS                    ///
    ///                                                          ///

    /// @notice Updates the contract image
    /// @param _newContractImage The new contract image
    function updateContractImage(string memory _newContractImage) external onlyOwner {
        emit ContractImageUpdated(settings.contractImage, _newContractImage);

        settings.contractImage = _newContractImage;
    }

    /// @notice Updates the collection description
    /// @param _newDescription The new description
    function updateDescription(string memory _newDescription) external onlyOwner {
        emit DescriptionUpdated(settings.description, _newDescription);

        settings.description = _newDescription;
    }

    function updateProjectURI(string memory _newProjectURI) external onlyOwner {
        emit WebsiteURIUpdated(settings.projectURI, _newProjectURI);

        settings.projectURI = _newProjectURI;
    }

    ///                                                          ///
    ///                        METADATA UPGRADE                  ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract to a valid implementation
    /// @dev This function is called in UUPS `upgradeTo` & `upgradeToAndCall`
    /// @param _impl The address of the new implementation
    function _authorizeUpgrade(address _impl) internal view override onlyOwner {
        if (!manager.isRegisteredUpgrade(_getImplementation(), _impl)) revert INVALID_UPGRADE(_impl);
    }
}
