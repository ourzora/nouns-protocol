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

    function setContractMetadata(bytes memory data) external;

    function setContractImage(string memory newContractImage) external;

    function setBaseRenderer(string memory newRenderer) external;

    function addProperties(
        string[] memory _newProperties,
        ItemInfoStorage[] memory _items,
        bytes memory _data
    ) external;

    function getProperties(uint256 tokenId) external view returns (bytes memory aryAttributes, bytes memory queryString);

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
