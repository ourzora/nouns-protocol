// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {IToken} from "../../IToken.sol";

contract MetadataRendererStorageV1 {
    uint8 internal constant DATA_TYPE_IPFS_SINGULAR = 0;
    uint8 internal constant DATA_TYPE_IPFS_GROUP = 1;
    uint8 internal constant DATA_TYPE_CENTRALIZED = 2;

    IToken public token;

    string internal name;
    string internal description;
    string internal contractImage;
    string internal rendererBase;

    mapping(uint256 => uint16[11]) attributes;

    bytes[] internal data;

    Property[] internal properties;

    struct Property {
        string name;
        Item[] items;
    }

    struct Item {
        uint8 dataType;
        uint16 referenceSlot;
        string name;
        bytes info;
    }
}
