// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {LibUintToString} from "sol2string/LibUintToString.sol";

import {MetadataRendererStorageV1} from "./storage/MetadataRendererStorageV1.sol";
import {IToken} from "../IToken.sol";
import {IMetadataRenderer} from "./IMetadataRenderer.sol";
import {IUpgradeManager} from "../../upgrade/IUpgradeManager.sol";

/// @title Metadata Renderer
/// @author Iain Nash & Rohan Kulkarni
/// @notice
contract MetadataRenderer is IMetadataRenderer, UUPSUpgradeable, OwnableUpgradeable, MetadataRendererStorageV1 {
    /// @dev Don't allow factory contract to be initialized
    constructor() payable initializer {}

    event DescriptionUpdated(string);
    event PropertyAdded(uint256 id, string name);
    event ItemAdded(uint256 propertyId, uint256 itemIndex);

    function initialize(
        address _foundersDAO,
        string calldata _name,
        string calldata _description,
        string calldata _contractImage,
        string calldata _rendererBase
    ) external initializer {
        // Initialize ownership
        __Ownable_init();

        // Store the associated token
        token = IToken(msg.sender);

        // Set the base information on the contract.
        name = _name;
        description = _description;
        contractImage = _contractImage;
        rendererBase = _rendererBase;

        // Transfer ownership to the founders
        transferOwnership(_foundersDAO);
    }

    function updateDescription(string memory newDescription) external onlyOwner {
        description = newDescription;
        emit DescriptionUpdated(newDescription);
    }

    /// @notice Get the number of properties
    /// @return count of properties
    function propertiesCount() external view returns (uint256) {
        return properties.length;
    }

    /// @notice Get the number of items in a property
    /// @param _propertyId ID of the property to get items for
    function itemsCount(uint256 _propertyId) external view returns (uint256) {
        return properties[_propertyId].items.length;
    }

    function addProperties(
        string[] calldata _names,
        ItemParam[] calldata _items,
        IPFSGroup calldata _ipfsGroup
    ) external onlyOwner {
        // Cache data length
        uint256 dataLength = data.length;

        // Add IPFS group information
        data.push(_ipfsGroup);

        // Cache the number of properties that already exist
        uint256 numStoredProperties = properties.length;

        // Cache the number of new properties to add
        uint256 numNewProperties = _names.length;

        // Cache the number of new items to add
        uint256 numNewItems = _items.length;

        // Used to store each new property id
        uint256 propertyId;

        // For each new property:
        for (uint256 i = 0; i < numNewProperties; ) {
            // Append one slot of storage space
            properties.push();

            unchecked {
                // Compute the property id
                propertyId = numStoredProperties + i;
            }

            // Store the property name
            properties[propertyId].name = _names[i];

            emit PropertyAdded(propertyId, name);

            unchecked {
                ++i;
            }
        }

        // For each new item:
        for (uint256 i = 0; i < numNewItems; ) {
            // Cache its property id
            uint256 _propertyId = _items[i].propertyId;

            // 100 - x = uses only new properties x >= 100
            // x = uses current properties where x < 100

            // Offset the IDs for new properties
            if (_items[i].isNewProperty) {
                //
                unchecked {
                    _propertyId += numStoredProperties;
                }
            }

            // Get the storage location of its property's items
            // Property IDs under the hood are offset by 1
            Item[] storage propertyItems = properties[_propertyId].items;

            // Append one slot of storage space
            propertyItems.push();

            // Used to store the new item
            Item storage newItem;

            // Used to store the index of the new item
            uint256 newItemIndex;

            // Cannot underflow as `propertyItems.length` is ensured to be at least 1
            unchecked {
                newItemIndex = propertyItems.length - 1;
            }

            // Store the new item
            newItem = propertyItems[newItemIndex];

            // Store its associated metadata
            newItem.name = _items[i].name;
            newItem.referenceSlot = uint16(dataLength);

            emit ItemAdded(_propertyId, newItemIndex);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Generates token information
    /// @param _tokenId id of the token to generate
    function generate(uint256 _tokenId) external {
        // Ensure the caller is the token contract
        require(msg.sender == address(token), "ONLY_TOKEN");

        // Compute some randomness
        uint256 entropy = _getEntropy(_tokenId);

        // Get the storage location for the token attributes
        uint16[16] storage tokenAttributes = attributes[_tokenId];

        // Cache the number of properties to choose from
        uint256 numProperties = properties.length;

        // Store that number for future reference
        tokenAttributes[0] = uint16(numProperties);

        // Used to store the number of items choosing from each property
        uint256 numItems;

        // For each property:
        for (uint256 i = 0; i < numProperties; ) {
            // Get the number of items
            numItems = properties[i].items.length;

            unchecked {
                // Use the previously generated randomness to choose one item in the property
                tokenAttributes[i + 1] = uint16(entropy % numItems);

                // Adjust the randomness
                entropy >>= 16;

                ++i;
            }
        }
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function _getEntropy(uint256 seed) private view returns (uint256) {
        return uint256(keccak256(abi.encode(seed, blockhash(block.number), block.coinbase, block.timestamp)));
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function contractURI() external view returns (string memory) {
        return string(abi.encodePacked('{"name": "', name, '", "description": "', description, '", "image": "', contractImage, '"}'));
    }

    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        (bytes memory propertiesAry, bytes memory propertiesQuery) = getProperties(_tokenId);
        return
            string(
                abi.encodePacked(
                    '{"name": "',
                    name,
                    " #",
                    LibUintToString.toString(_tokenId),
                    '", "description": "',
                    description,
                    '", "image": "',
                    rendererBase,
                    propertiesQuery,
                    '", "properties": {',
                    propertiesAry,
                    "}}"
                )
            );
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function getProperties(uint256 _tokenId) public view returns (bytes memory aryAttributes, bytes memory queryString) {
        // Get the attributes for the given token
        uint16[16] memory tokenAttributes = attributes[_tokenId];

        // Compute its query string
        queryString = abi.encodePacked(
            "contractAddress=",
            StringsUpgradeable.toHexString(uint256(uint160(address(this))), 20),
            "&tokenId=",
            StringsUpgradeable.toString(_tokenId)
        );

        // Cache its number of properties
        uint256 numProperties = tokenAttributes[0];

        // Used to hold the property and item data during
        Property memory property;
        Item memory item;

        // Used to cache the property and item names
        string memory propertyName;
        string memory itemName;

        // Used to get the item data of each generated attribute
        uint256 attribute;

        // Used to
        bool isLast;

        // For each of the token's properties:
        for (uint256 i = 0; i < numProperties; ) {
            //
            unchecked {
                // Check if this is the last iteration
                isLast = i == (numProperties - 1);
            }

            // Get the property data
            property = properties[i];

            unchecked {
                // Get the index of its generated attribute for this property
                attribute = tokenAttributes[i + 1];
            }

            // Get the associated item data
            item = property.items[attribute];

            // Cache the names of the property and item
            propertyName = property.name;
            itemName = item.name;

            //
            aryAttributes = abi.encodePacked(aryAttributes, '"', propertyName, '": "', itemName, '"', isLast ? "" : ",");
            queryString = abi.encodePacked(queryString, "&", propertyName, "=", itemName, "&images[]=", _getImageForItem(item, propertyName), "&");

            unchecked {
                ++i;
            }
        }
    }

    function _getImageForItem(Item memory _item, string memory _propertyName) internal view returns (bytes memory) {
        return abi.encodePacked(data[_item.referenceSlot].baseUri, _item.name, "/", _propertyName, data[_item.referenceSlot].extension);
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function owner() public view override(IMetadataRenderer, OwnableUpgradeable) returns (address) {
        return super.owner();
    }

    function transferOwnership(address _newOwner) public override(IMetadataRenderer, OwnableUpgradeable) {
        return super.transferOwnership(_newOwner);
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
        require(token.upgradeManager().isValidUpgrade(_getImplementation(), newImplementation), "INVALID_UPGRADE");
    }
}
