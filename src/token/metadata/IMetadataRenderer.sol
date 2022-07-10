// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

interface IMetadataRenderer {
    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function initialize(
        address _foundersDAO,
        string calldata _name,
        string calldata _description,
        string calldata _contractImage,
        string calldata _rendererBase
    ) external;

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    struct ItemParam {
        uint256 propertyId;
        uint256 dataType;
        string name;
        bytes info;
    }

    function addProperties(
        string[] calldata names,
        ItemParam[] calldata items,
        bytes calldata data
    ) external;

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function contractURI() external view returns (string memory);

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function propertiesCount() external view returns (uint256);

    function itemsCount(uint256 propertyId) external view returns (uint256);

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function getProperties(uint256 tokenId) external view returns (bytes memory aryAttributes, bytes memory queryString);

    function generate(uint256 tokenId) external;

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function owner() external returns (address);

    function transferOwnership(address newOwner) external;
}
