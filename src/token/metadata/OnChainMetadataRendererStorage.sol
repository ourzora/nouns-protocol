// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {IToken} from "../IToken.sol";

contract OnChainMetadataRendererStorage {
    struct Item {
        string name;
        // uint32 chunkId;
        // uint32 startOffset;
        // uint32 endOffset;
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

    string name;
    string description;
    string imageBase;

    IToken token;

    mapping(uint256 => uint16[11]) chosenAttributes;
    mapping(uint16 => Item[]) items;
}