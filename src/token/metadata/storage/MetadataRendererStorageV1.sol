// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {IToken} from "../../IToken.sol";
import {IMetadataRenderer} from "../IMetadataRenderer.sol";

contract MetadataRendererStorageV1 {
    uint8 internal constant DATA_TYPE_IPFS_SINGULAR = 0;
    uint8 internal constant DATA_TYPE_IPFS_GROUP = 1;
    uint8 internal constant DATA_TYPE_CENTRALIZED = 2;

    IToken internal token;

    string internal name;
    string internal description;
    string internal contractImage;
    string internal rendererBase;

    IMetadataRenderer.Property[] internal properties;
    bytes[] internal data;

    mapping(uint256 => uint16[11]) chosenAttributes;
    mapping(uint16 => IMetadataRenderer.Item[]) items;
}
