// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {IToken} from "../IToken.sol";

contract OnChainMetadataRendererStorage {
    uint8 constant internal DATA_TYPE_IPFS = 1;
    uint8 constant internal DATA_TYPE_CENTRALIZED = 2;
    uint8 constant internal DATA_TYPE_ONCHAIN_RLE = 3;

    struct Item {
        string name;
        uint8 dataType;
        bytes data;
    }

    struct ItemWithPropertyId {
        Item item;
        uint16 propertyId;
    }

    struct Property {
        string name;
        Item[] items;
    }

    Property[] properties;
    address[] chunks;

    string name;
    string description;
    string imageBase;

    IToken token;

    mapping(uint256 => uint16[11]) chosenAttributes;
    mapping(uint16 => Item[]) items;
}