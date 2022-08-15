// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

interface MetadataRendererTypesV1 {
    struct ItemParam {
        uint256 propertyId;
        string name;
        bool isNewProperty;
    }

    struct IPFSGroup {
        string baseUri;
        string extension;
    }

    struct Item {
        uint16 referenceSlot;
        string name;
    }

    struct Property {
        string name;
        Item[] items;
    }

    struct Settings {
        address token;
        address treasury;
        string name;
        string description;
        string contractImage;
        string rendererBase;
    }
}
