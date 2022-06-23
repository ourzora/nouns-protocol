// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {LibUintToString} from "sol2string/LibUintToString.sol";
import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {OnChainMetadataRendererStorage} from "./OnChainMetadataRendererStorage.sol";
import {EntropyUser} from "./EntropyUser.sol";

import {IToken} from "../IToken.sol";
import {IMetadataRenderer} from "./IMetadataRenderer.sol";
import {IUpgradeManager} from "../../upgrade/IUpgradeManager.sol";

contract OnChainMetadataRenderer is UUPSUpgradeable, OnChainMetadataRendererStorage, EntropyUser, IMetadataRenderer {
    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    constructor() payable initializer {
        // prevent calling directly
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function initialize(bytes memory data) external initializer {
        (string memory _name, string memory _description, string memory _contractImage, string memory _rendererBase) = abi.decode(
            data,
            (string, string, string, string)
        );

        name = _name;
        description = _description;
        rendererBase = _rendererBase;
        contractImage = _contractImage;

        token = IToken(msg.sender);
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    // TODO access controls?
    function addProperties(
        string[] memory _newProperties,
        ItemInfoStorage[] memory _items,
        bytes memory _data
    ) public {
        uint256 propertiesBaseLength = properties.length;
        uint256 dataBaseLength = data.length;

        if (_data.length > 0) {
            data.push(_data);
        }

        for (uint256 i = 0; i < _newProperties.length; i++) {
            properties.push();
            properties[propertiesBaseLength + i].name = _newProperties[i];
        }

        for (uint256 i = 0; i < _items.length; i++) {
            // 100 - x = uses only new properties x >= 100
            // x = uses current properties where x < 100
            uint256 id = _items[i].propertyId >= 100 ? _items[i].propertyId + propertiesBaseLength - 100 : _items[i].propertyId;
            properties[id].items.push();
            uint256 newLength = properties[id].items.length;
            Item storage item = properties[id].items[newLength - 1];
            item.dataType = _items[i].dataType;
            item.referenceSlot = uint16(dataBaseLength);
            item.info = _items[i].info;
            item.name = _items[i].name;
        }
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    event NewContractImage(string indexed);

    function setContractImage(string memory newContractImage) public {
        require(msg.sender == token.foundersDAO(), "ONLY_FOUNDERS");

        contractImage = newContractImage;

        emit NewContractImage(contractImage);
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    event NewBaseRenderer(string indexed);

    function setBaseRenderer(string memory newRenderer) public {
        require(msg.sender == token.foundersDAO(), "ONLY_FOUNDERS");

        rendererBase = newRenderer;

        emit NewBaseRenderer(newRenderer);
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function getProperties(uint256 tokenId) public view returns (bytes memory aryAttributes, bytes memory queryString) {
        uint16[11] storage atAttributes = chosenAttributes[tokenId];
        queryString = abi.encodePacked(
            "contractAddress=",
            StringsUpgradeable.toHexString(uint256(uint160(address(this))), 20),
            "&tokenId=",
            StringsUpgradeable.toString(tokenId)
        );

        for (uint256 i = 0; i < atAttributes[0]; i++) {
            bool isLast = i == atAttributes[0] - 1;
            Item storage item = properties[i].items[atAttributes[i + 1]];
            string memory propertyName = properties[i].name;
            aryAttributes = abi.encodePacked(aryAttributes, '"', propertyName, '": "', item.name, '"', isLast ? "" : ",");
            queryString = abi.encodePacked(queryString, "&", propertyName, "=", item.name, "&images[]=", _getImageForItem(item, propertyName), "&");
        }
    }

    function _getImageForItem(Item storage item, string memory propertyName) internal view returns (string memory) {
        if (item.dataType == DATA_TYPE_IPFS_SINGULAR) {
            return string(abi.encodePacked("ipfs://", item.info));
        }
        if (item.dataType == DATA_TYPE_IPFS_GROUP) {
            (string memory base, string memory postfix) = abi.decode(data[item.referenceSlot], (string, string));
            return string(abi.encodePacked("ipfs://", base, "/", propertyName, "/", item.name, postfix));
        }
        if (item.dataType == DATA_TYPE_CENTRALIZED) {
            // ignore image paths for centralized, pass in specific data if needed.
            return string(abi.encodePacked("data:", item.info));
        }
        return "";
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function contractURI() external view returns (string memory) {
        return string(abi.encodePacked('{"name": "', name, '", "description": "', description, '", "image": "', contractImage, '"}'));
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        (bytes memory propertiesAry, bytes memory propertiesQuery) = getProperties(tokenId);
        return
            string(
                abi.encodePacked(
                    '{"name": "',
                    name,
                    " #",
                    LibUintToString.toString(tokenId),
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

    function minted(uint256 tokenId) external {
        require(msg.sender == address(token), "ONLY_TOKEN");

        uint256 entropy = _getEntropy(tokenId);
        uint16[11] storage atAttributes = chosenAttributes[tokenId];
        atAttributes[0] = uint16(properties.length);
        for (uint256 i = 0; i < properties.length; i++) {
            uint16 size = uint16(properties[i].items.length);
            atAttributes[i + 1] = uint16(entropy) % size;
            entropy >>= 16;
        }
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    // TODO access controls?
    function _authorizeUpgrade(address newImplementation) internal override {
        require(token.UpgradeManager().isValidUpgrade(_getImplementation(), newImplementation), "INVALID_UPGRADE");
    }
}
