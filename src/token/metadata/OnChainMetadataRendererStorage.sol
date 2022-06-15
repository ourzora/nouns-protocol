// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {IToken} from "../IToken.sol";

contract OnChainMetadataRendererStorage {
    uint8 constant internal DATA_TYPE_IPFS_SINGULAR = 1;
    uint8 constant internal DATA_TYPE_IPFS_GROUP = 2;
    uint8 constant internal DATA_TYPE_CENTRALIZED = 3;

    struct Item {
        uint8 dataType;
        uint16 referenceSlot;
        string name;
        bytes info;
    }

    struct ItemInfoStorage {
        uint256 propertyId;
        uint8 dataType;
        string name;
        bytes info;
    }

    struct Property {
        string name;
        Item[] items;
    }

    Property[] properties;
    bytes[] data;

    string name;
    string description;
    string contractImage;
    string rendererBase;

    IToken token;

    mapping(uint256 => uint16[11]) chosenAttributes;
    mapping(uint16 => Item[]) items;
}