// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { LibUintToString } from "sol2string/contracts/LibUintToString.sol";
import { UriEncode } from "sol-uriencode/src/UriEncode.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";

import { UUPS } from "../../lib/proxy/UUPS.sol";
import { Ownable } from "../../lib/utils/Ownable.sol";
import { Strings } from "../../lib/utils/Strings.sol";

import { MetadataRendererStorageV1 } from "./storage/MetadataRendererStorageV1.sol";
import { IPropertyIPFSMetadataRenderer } from "./interfaces/IPropertyIPFSMetadataRenderer.sol";
import { IManager } from "../../manager/IManager.sol";

/// @title Metadata Renderer
/// @author Iain Nash & Rohan Kulkarni
/// @notice DAO token metadata renderer
contract MetadataRenderer is IPropertyIPFSMetadataRenderer, UUPS, Ownable, MetadataRendererStorageV1 {
    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IManager private immutable manager;

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    /// @param _manager The address of the contract upgrade manager
    constructor(address _manager) payable initializer {
        manager = IManager(_manager);
    }

    ///                                                          ///
    ///                          INITIALIZER                     ///
    ///                                                          ///

    /// @notice Initializes a DAO's token metadata renderer
    /// @param _initStrings The encoded token and metadata initialization strings
    /// @param _token The ERC-721 token address
    /// @param _founder The founder address responsible for adding initial properties
    /// @param _treasury The DAO treasury that will own the contract
    function initialize(
        bytes calldata _initStrings,
        address _token,
        address _founder,
        address _treasury
    ) external initializer {
        // Ensure the caller is the contract manager
        if (msg.sender != address(manager)) revert ONLY_MANAGER();

        // Decode the token initialization strings
        (string memory _name, , string memory _description, string memory _contractImage, string memory _rendererBase) = abi.decode(
            _initStrings,
            (string, string, string, string, string)
        );

        // Store the renderer settings
        settings.name = _name;
        settings.description = _description;
        settings.contractImage = _contractImage;
        settings.rendererBase = _rendererBase;
        settings.token = _token;
        settings.treasury = _treasury;

        // Grant initial ownership to a founder
        __Ownable_init(_founder);
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

    /// @notice Adds properties and/or items to be pseudo-randomly chosen from during token minting
    /// @param _names The names of the properties to add
    /// @param _items The items to add to each property
    /// @param _ipfsGroup The IPFS base URI and extension
    function addProperties(
        string[] calldata _names,
        ItemParam[] calldata _items,
        IPFSGroup calldata _ipfsGroup
    ) external onlyOwner {
        // Cache the existing amount of IPFS data stored
        uint256 dataLength = ipfsData.length;

        // If this is the first time adding properties and/or items:
        if (dataLength == 0) {
            // Transfer ownership to the DAO treasury
            transferOwnership(settings.treasury);
        }

        // Add the IPFS group information
        ipfsData.push(_ipfsGroup);

        // Cache the number of existing properties
        uint256 numStoredProperties = properties.length;

        // Cache the number of new properties adding
        uint256 numNewProperties = _names.length;

        // Cache the number of new items adding
        uint256 numNewItems = _items.length;

        unchecked {
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
                if (_items[i].isNewProperty) {
                    _propertyId += numStoredProperties;
                }

                // Get the pointer to the  of the other items for the property
                // Note: Property ids under the hood are offset by 1
                Item[] storage propertyItems = properties[_propertyId].items;

                // Append storage space
                propertyItems.push();

                // Get the index of the
                // Cannot underflow as the array push() ensures the length to be at least 1
                uint256 newItemIndex = propertyItems.length - 1;

                // Store the new item
                Item storage newItem = propertyItems[newItemIndex];

                // Store its associated metadata
                newItem.name = _items[i].name;
                newItem.referenceSlot = uint16(dataLength);

                emit ItemAdded(_propertyId, newItemIndex);
            }
        }
    }

    ///                                                          ///
    ///                     ATTRIBUTE GENERATION                 ///
    ///                                                          ///

    /// @notice Generates attributes for a token upon mint
    /// @param _tokenId The ERC-721 token id
    function onMinted(uint256 _tokenId) external returns (bool) {
        // Ensure the caller is the token contract
        if (msg.sender != settings.token) revert ONLY_TOKEN();

        // Compute some randomness for the token id
        uint256 seed = _generateSeed(_tokenId);

        // Get the location to where the attributes should be stored after generation
        uint16[16] storage tokenAttributes = attributes[_tokenId];

        // Cache the number of total properties to choose from
        uint256 numProperties = properties.length;

        // Store the number of properties in the first slot of the token's array for reference
        tokenAttributes[0] = uint16(numProperties);

        // Used to store the number of items in each property
        uint256 numItems;

        unchecked {
            // For each property:
            for (uint256 i = 0; i < numProperties; ++i) {
                // Get the number of items to choose from
                numItems = properties[i].items.length;

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
    function getAttributes(uint256 _tokenId) public view returns (bytes memory aryAttributes, bytes memory queryString) {
        // Compute its query string
        queryString = abi.encodePacked(
            "?contractAddress=",
            Strings.toHexString(uint256(uint160(address(this))), 20),
            "&tokenId=",
            Strings.toString(_tokenId)
        );

        // Get the attributes for the given token
        uint16[16] memory tokenAttributes = attributes[_tokenId];

        // Cache the number of properties stored when the token was minted
        uint256 numProperties = tokenAttributes[0];

        // Ensure the token
        if (numProperties == 0) revert TOKEN_NOT_MINTED(_tokenId);

        unchecked {
            // Cache the index of the last property
            uint256 lastProperty = numProperties - 1;

            // For each of the token's properties:
            for (uint256 i = 0; i < numProperties; ++i) {
                // Check if this is the last iteration
                bool isLast = i == lastProperty;

                // Get a copy of the property
                Property memory property = properties[i];

                // Get the index of its generated attribute for this property
                uint256 attribute = tokenAttributes[i + 1];

                // Get the associated item data
                Item memory item = property.items[attribute];

                aryAttributes = abi.encodePacked(aryAttributes, '"', property.name, '": "', item.name, '"', isLast ? "" : ",");
                queryString = abi.encodePacked(queryString, "&images=", _getItemImage(item, property.name));
            }
        }
    }

    /// @dev Generates a psuedo-random seed for a token id
    function _generateSeed(uint256 _tokenId) private view returns (uint256) {
        return uint256(keccak256(abi.encode(_tokenId, blockhash(block.number), block.coinbase, block.timestamp)));
    }

    /// @dev Encodes the string from an item in a property
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

    /// @notice The contract URI
    function contractURI() external view returns (string memory) {
        return
            _encodeAsJson(
                abi.encodePacked(
                    '{"name": "',
                    settings.name,
                    '", "description": "',
                    settings.description,
                    '", "image": "',
                    settings.contractImage,
                    '"}'
                )
            );
    }

    /// @notice The token URI
    /// @param _tokenId The ERC-721 token id
    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        (bytes memory aryAttributes, bytes memory queryString) = getAttributes(_tokenId);
        return
            _encodeAsJson(
                abi.encodePacked(
                    '{"name": "',
                    settings.name,
                    " #",
                    LibUintToString.toString(_tokenId),
                    '", "description": "',
                    settings.description,
                    '", "image": "',
                    settings.rendererBase,
                    queryString,
                    '", "properties": {',
                    aryAttributes,
                    "}}"
                )
            );
    }

    /// @dev Converts JSON bytes to Bytes64
    function _encodeAsJson(bytes memory _jsonBlob) private pure returns (string memory) {
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(_jsonBlob)));
    }

    ///                                                          ///
    ///                       METADATA SETTINGS                  ///
    ///                                                          ///

    /// @notice The DAO governance token
    function token() external view returns (address) {
        return settings.token;
    }

    /// @notice The DAO treasury
    function treasury() external view returns (address) {
        return settings.treasury;
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

    ///                                                          ///
    ///                       UPDATE SETTINGS                    ///
    ///                                                          ///

    /// @notice Updates the contract image
    /// @param _newImage The new contract image
    function updateContractImage(string memory _newImage) external onlyOwner {
        emit ContractImageUpdated(settings.contractImage, _newImage);

        settings.contractImage = _newImage;
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
