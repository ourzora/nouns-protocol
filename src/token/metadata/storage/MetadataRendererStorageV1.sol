// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { MetadataRendererTypesV1 } from "../types/MetadataRendererTypesV1.sol";

/// @title MetadataRendererTypesV1
/// @author Iain Nash & Rohan Kulkarni
/// @notice The Metadata Renderer storage contract
contract MetadataRendererStorageV1 is MetadataRendererTypesV1 {
    Settings internal settings;

    IPFSGroup[] internal ipfsData;
    Property[] internal properties;

    mapping(uint256 => uint16[16]) internal attributes;
}
