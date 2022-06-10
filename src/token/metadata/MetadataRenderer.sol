// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {IMetadataRenderer} from "./IMetadataRenderer.sol";
import {EntropyUser} from "./EntropyUser.sol";

contract OnChainMetadataRenderer is UUPSUpgradeable {
    struct Item {
        string name;
        uint32 chunkId;
        uint32 startOffset;
        uint32 endOffset;
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
    mapping(uint256 => uint16[11]) chosenAttributes;
}

contract OnChainMetadataRenderer is UUPSUpgradeable, OffchainMetadataStorage, EntropyUser {
    function setup(Property[] memory _properties) {
        properties = _properties;
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
        (bytes memory propertiesAry, bytes memory propertiesQuery) = _getProperties();
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
                    _getPropertiesImage(tokenId),
                    '", "properties": {',
                    _getPropertiesAttributes(tokenId),
                    "}}"
                )
            );
    }

    function minted(uint256 tokenId) external {
        uint256 entropy = _getEntropy();
        uint16[11] storage atAttributes = chosenAttributes[tokenId];
        atAttributes[0] = properties.length;
        for (uint256 i = 0; i < properties.length; i++) {
            uint256 size = properties[i].items.length;
            atAttributes[i + 1] = uint16(entropy) % size;
            entropy >>= 16;
        }
    }
}
