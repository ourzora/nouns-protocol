// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {IToken} from "../../IToken.sol";
import {IMetadataRenderer} from "../IMetadataRenderer.sol";

contract MetadataRendererStorageV1 {
    IToken public token;

    string internal name;
    string internal description;
    string internal contractImage;
    string internal rendererBase;

    mapping(uint256 => uint16[16]) attributes;

    IMetadataRenderer.IPFSGroup[] internal data;

    Property[] internal properties;

    struct Property {
        string name;
        Item[] items;
    }

    struct Item {
        uint16 referenceSlot;
        string name;
    }
}
