// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {MetadataRendererTypesV1} from "../types/MetadataRendererTypesV1.sol";

contract MetadataRendererStorageV1 is MetadataRendererTypesV1 {
    Settings internal settings;

    IPFSGroup[] internal ipfsData;
    Property[] internal properties;

    mapping(uint256 => uint16[16]) internal attributes;
}
