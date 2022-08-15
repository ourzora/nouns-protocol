// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {MetadataRendererTypesV1} from "./types/MetadataRendererTypesV1.sol";

interface IMetadataRenderer is MetadataRendererTypesV1 {
    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    event PropertyAdded(uint256 id, string name);

    event ItemAdded(uint256 propertyId, uint256 index);

    event ContractImageUpdated(string prevImage, string newImage);

    event RendererBaseUpdated(string prevRendererBase, string newRendererBase);

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    error ONLY_TOKEN();

    error TOKEN_NOT_MINTED(uint256 tokenId);

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function initialize(
        bytes calldata initStrings,
        address token,
        address founders,
        address treasury
    ) external;

    function addProperties(
        string[] calldata names,
        ItemParam[] calldata items,
        IPFSGroup calldata ipfsGroup
    ) external;

    function updateContractImage(string memory newContractImage) external;

    function updateRendererBase(string memory newRendererBase) external;

    function propertiesCount() external view returns (uint256);

    function itemsCount(uint256 propertyId) external view returns (uint256);

    function generate(uint256 tokenId) external;

    function getAttributes(uint256 tokenId) external view returns (bytes memory aryAttributes, bytes memory queryString);

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function contractURI() external view returns (string memory);

    function token() external view returns (address);

    function treasury() external view returns (address);

    function contractImage() external view returns (string memory);

    function rendererBase() external view returns (string memory);

    function description() external view returns (string memory);
}
