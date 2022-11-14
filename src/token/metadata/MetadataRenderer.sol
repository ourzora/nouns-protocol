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

import { MetadataRendererStorageV1 } from "./storage/MetadataRendererStorageV1.sol";
import { MetadataRendererStorageV2 } from "./storage/MetadataRendererStorageV2.sol";
import { IToken } from "../../token/IToken.sol";
import { IPropertyIPFSMetadataRenderer } from "./interfaces/IPropertyIPFSMetadataRenderer.sol";
import { IManager } from "../../manager/IManager.sol";

/// @title Metadata Renderer
/// @author Iain Nash & Rohan Kulkarni
/// @notice A DAO's artwork generator and renderer
contract MetadataRenderer is IPropertyIPFSMetadataRenderer, Initializable, UUPS, MetadataRendererStorageV1, MetadataRendererStorageV2 {
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
    /// @param _initStrings The encoded token and metadata initialization strings
    /// @param _token The ERC-721 token address
    function initialize(bytes calldata _initStrings, address _token) external initializer {
        // Ensure the caller is the contract manager
        if (msg.sender != address(manager)) {
            revert ONLY_MANAGER();
        }

        // Decode the token initialization strings
        (, , string memory _description, string memory _contractImage, string memory _projectURI, string memory _rendererBase) = abi.decode(
            _initStrings,
            (string, string, string, string, string, string)
        );

        // Store the renderer settings
        settings.projectURI = _projectURI;
        settings.description = _description;
        settings.contractImage = _contractImage;
        settings.rendererBase = _rendererBase;
        settings.projectURI = _projectURI;
        settings.token = _token;
    }

    ///                                                          ///
    ///                     PROPERTIES & ITEMS                   ///
    ///                                                          ///

    /// @notice The number of properties
    function propertiesCount() external view returns (uint256) {
        return properties.length;
    }

    /// @notice The number of items in a property
    /// @param _propertyId The property id
    function itemsCount(uint256 _propertyId) external view returns (uint256) {
        return properties[_propertyId].items.length;
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

    /// @notice Adds properties and/or items to be pseudo-randomly chosen from during token minting
    /// @param _names The names of the properties to add
    /// @param _items The items to add to each property
    /// @param _ipfsGroup The IPFS base URI and extension
    function addProperties(
        string[] calldata _names,
        ItemParam[] calldata _items,
        IPFSGroup calldata _ipfsGroup
    ) external onlyOwner {
        _addProperties(_names, _items, _ipfsGroup);
    }

    /// @notice Deletes existing properties and/or items to be pseudo-randomly chosen from during token minting, replacing them with provided properties. WARNING: This function can alter or break existing token metadata if the number of properties for this renderer change before/after the upsert. If the properties selected in any tokens do not exist in the new version those token will not render
    /// @dev We do not require the number of properties for an reset to match the existing property length, to allow multi-stage property additions (for e.g. when there are more properties than can fit in a single transaction)
    /// @param _names The names of the properties to add
    /// @param _items The items to add to each property
    /// @param _ipfsGroup The IPFS base URI and extension
    function deleteAndRecreateProperties(
        string[] calldata _names,
        ItemParam[] calldata _items,
        IPFSGroup calldata _ipfsGroup
    ) external onlyOwner {
        delete ipfsData;
        delete properties;
        _addProperties(_names, _items, _ipfsGroup);
    }

    function _addProperties(
        string[] calldata _names,
        ItemParam[] calldata _items,
        IPFSGroup calldata _ipfsGroup
    ) internal {
        // Cache the existing amount of IPFS data stored
        uint256 dataLength = ipfsData.length;

        // Add the IPFS group information
        ipfsData.push(_ipfsGroup);

        // Cache the number of existing properties
        uint256 numStoredProperties = properties.length;

        // Cache the number of new properties
        uint256 numNewProperties = _names.length;

        // Cache the number of new items
        uint256 numNewItems = _items.length;

        // If this is the first time adding metadata:
        if (numStoredProperties == 0) {
            // Ensure at least one property and one item are included
            if (numNewProperties == 0 || numNewItems == 0) {
                revert ONE_PROPERTY_AND_ITEM_REQUIRED();
            }
        }

        unchecked {
            // Check if not too many items are stored
            if (numStoredProperties + numNewProperties > 15) {
                revert TOO_MANY_PROPERTIES();
            }

            // For each new property:
            for (uint256 i = 0; i < numNewProperties; ++i) {
                // Append storage space
                properties.push();

                // Get the new property id
                uint256 propertyId = numStoredProperties + i;

                // Store the property name
                properties[propertyId].name = _names[i];

                emit PropertyAdded(propertyId, _names[i]);
            }

            // For each new item:
            for (uint256 i = 0; i < numNewItems; ++i) {
                // Cache the id of the associated property
                uint256 _propertyId = _items[i].propertyId;

                // Offset the id if the item is for a new property
                // Note: Property ids under the hood are offset by 1
                if (_items[i].isNewProperty) {
                    _propertyId += numStoredProperties;
                }

                // Ensure the item is for a valid property
                if (_propertyId >= properties.length) {
                    revert INVALID_PROPERTY_SELECTED(_propertyId);
                }

                // Get the pointer to the other items for the property
                Item[] storage items = properties[_propertyId].items;

                // Append storage space
                items.push();

                // Get the index of the new item
                // Cannot underflow as the items array length is ensured to be at least 1
                uint256 newItemIndex = items.length - 1;

                // Store the new item
                Item storage newItem = items[newItemIndex];

                // Store the new item's name and reference slot
                newItem.name = _items[i].name;
                newItem.referenceSlot = uint16(dataLength);
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

        // Compute some randomness for the token id
        uint256 seed = _generateSeed(_tokenId);

        // Get the pointer to store generated attributes
        uint16[16] storage tokenAttributes = attributes[_tokenId];

        // Cache the total number of properties available
        uint256 numProperties = properties.length;

        if (numProperties == 0) {
            return false;
        }

        // Store the total as reference in the first slot of the token's array of attributes
        tokenAttributes[0] = uint16(numProperties);

        unchecked {
            // For each property:
            for (uint256 i = 0; i < numProperties; ++i) {
                // Get the number of items to choose from
                uint256 numItems = properties[i].items.length;

                // Use the token's seed to select an item
                tokenAttributes[i + 1] = uint16(seed % numItems);

                // Adjust the randomness
                seed >>= 16;
            }
        }

        return true;
    }

    /// @notice The properties and query string for a generated token
    /// @param _tokenId The ERC-721 token id
    function getAttributes(uint256 _tokenId) public view returns (string memory resultAttributes, string memory queryString) {
        // Get the token's query string
        queryString = string.concat(
            "?contractAddress=",
            Strings.toHexString(uint256(uint160(address(this))), 20),
            "&tokenId=",
            Strings.toString(_tokenId)
        );

        // Get the token's generated attributes
        uint16[16] memory tokenAttributes = attributes[_tokenId];

        // Cache the number of properties when the token was minted
        uint256 numProperties = tokenAttributes[0];

        // Ensure the given token was minted
        if (numProperties == 0) revert TOKEN_NOT_MINTED(_tokenId);

        // Get an array to store the token's generated attribtues
        MetadataBuilder.JSONItem[] memory arrayAttributesItems = new MetadataBuilder.JSONItem[](numProperties);

        unchecked {
            // For each of the token's properties:
            for (uint256 i = 0; i < numProperties; ++i) {
                // Get its name and list of associated items
                Property memory property = properties[i];

                // Get the randomly generated index of the item to select for this token
                uint256 attribute = tokenAttributes[i + 1];

                // Get the associated item data
                Item memory item = property.items[attribute];

                // Store the encoded attributes and query string
                MetadataBuilder.JSONItem memory itemJSON = arrayAttributesItems[i];

                itemJSON.key = property.name;
                itemJSON.value = item.name;
                itemJSON.quote = true;

                queryString = string.concat(queryString, "&images=", _getItemImage(item, property.name));
            }

            resultAttributes = MetadataBuilder.generateJSON(arrayAttributesItems);
        }
    }

    /// @dev Generates a psuedo-random seed for a token id
    function _generateSeed(uint256 _tokenId) private view returns (uint256) {
        return uint256(keccak256(abi.encode(_tokenId, blockhash(block.number), block.coinbase, block.timestamp)));
    }

    /// @dev Encodes the reference URI of an item
    function _getItemImage(Item memory _item, string memory _propertyName) private view returns (string memory) {
        return
            UriEncode.uriEncode(
                string(
                    abi.encodePacked(ipfsData[_item.referenceSlot].baseUri, _propertyName, "/", _item.name, ipfsData[_item.referenceSlot].extension)
                )
            );
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
        (string memory _attributes, string memory queryString) = getAttributes(_tokenId);

        MetadataBuilder.JSONItem[] memory items = new MetadataBuilder.JSONItem[](4 + additionalTokenProperties.length);

        items[0] = MetadataBuilder.JSONItem({
            key: MetadataJSONKeys.keyName,
            value: string.concat(_name(), " #", Strings.toString(_tokenId)),
            quote: true
        });
        items[1] = MetadataBuilder.JSONItem({ key: MetadataJSONKeys.keyDescription, value: settings.description, quote: true });
        items[2] = MetadataBuilder.JSONItem({
            key: MetadataJSONKeys.keyImage,
            value: string.concat(settings.rendererBase, queryString),
            quote: true
        });
        items[3] = MetadataBuilder.JSONItem({ key: MetadataJSONKeys.keyProperties, value: _attributes, quote: false });

        for (uint256 i = 0; i < additionalTokenProperties.length; i++) {
            AdditionalTokenProperty memory tokenProperties = additionalTokenProperties[i];
            items[4 + i] = MetadataBuilder.JSONItem({ key: tokenProperties.key, value: tokenProperties.value, quote: tokenProperties.quote });
        }

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

    /// @notice Updates the renderer base
    /// @param _newRendererBase The new renderer base
    function updateRendererBase(string memory _newRendererBase) external onlyOwner {
        emit RendererBaseUpdated(settings.rendererBase, _newRendererBase);

        settings.rendererBase = _newRendererBase;
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
