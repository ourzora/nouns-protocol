// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {IMetadataRenderer} from "./IMetadataRenderer.sol";
import {EntropyUser} from "./EntropyUser.sol";

contract OnChainMetadataRendererStorage {
    struct Item {
        string name;
        uint32 chunkId;
        uint32 startOffset;
        uint32 endOffset;
    }

    struct ItemWithPropertyId {
      Item item;
      uint16 propertyId; 
    }

    struct Property {
      string name;
      Item[] items;
    }

    struct MediaChunk {
        address data;
    }

    Property[] properties;
    uint32 size;
    string name;
    string description;
    string imageBase;
    mapping(uint256 => uint16[11]) chosenAttributes;
    mapping(uint16 => Item[]) items;
}

// TODO: make UUPSUpgradable
contract OnChainMetadataRenderer is OnChainMetadataRendererStorage, EntropyUser {
    event NewImageBaseURI(string indexed);

    function setup(string[] memory _properties, ItemWithPropertyId[] memory _items) public {
      for (uint256 i = 0; i < _properties.length; i++) {
        properties.push();
        properties[i].name = _properties[i];
      }
      for (uint256 i = 0; i < _items.length; i++) {
        properties[_items[i].propertyId].items.push();
        properties[_items[i].propertyId].items[i].name = _items[i].item.name;
      }
    }

    function setImageBase(string memory newImageBase) external {
      imageBase = newImageBase;
      emit NewImageBaseURI(newImageBase);
    }

    function contractURI() external view returns (string memory) {
        return string(abi.encodePacked('{"name": "', name, '", "description": "', description, '"}'));
    }

    function _getProperties(uint256 tokenId) internal view returns (bytes memory aryAttributes, bytes memory queryString) {
        uint16[11] storage atAttributes = chosenAttributes[tokenId];
        queryString = "?";
        for (uint256 i = 0; i < atAttributes[0]; i++) {
            bool isLast = i == atAttributes[0] - 1;
            string memory valueName = properties[i].items[atAttributes[i + 1]].name;
            aryAttributes = abi.encodePacked(aryAttributes, '"', properties[i].name, '": "', valueName, '"', isLast ? "" : ",");
            queryString = abi.encodePacked(aryAttributes, properties[i].name, "=", valueName, isLast ? "" : "&");
        }
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        (bytes memory propertiesAry, bytes memory propertiesQuery) = _getProperties(tokenId);
        return
            string(
                abi.encodePacked(
                    '{"name": "',
                    name,
                    " #",
                    tokenId,
                    '", "description": "',
                    description,
                    '", "image": "',
                    imageBase,
                    propertiesQuery,
                    '", "properties": {', 
                    propertiesAry,
                    "}}"
                )
            );
    }

    function minted(uint256 tokenId) external {
        uint256 entropy = _getEntropy(tokenId);
        uint16[11] storage atAttributes = chosenAttributes[tokenId];
        atAttributes[0] = uint16(properties.length);
        for (uint256 i = 0; i < properties.length; i++) {
            uint16 size = uint16(properties[i].items.length);
            atAttributes[i + 1] = uint16(entropy) % size;
            entropy >>= 16;
        }
    }
}
