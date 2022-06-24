// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface IMetadataRenderer {
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

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function initialize(address foundersDAO) external;

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function setAllMetadata(bytes memory data) external;

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///
    function contractURI() external view returns (string memory);

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function minted(uint256 tokenId) external;

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function owner() external returns (address);

    function transferOwnership(address newOwner) external;
}
