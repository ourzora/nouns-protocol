// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface IMetadataRenderer {
    function contractURI() external view returns (string memory);

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function minted(uint256 tokenId) external;

    function initialize(bytes memory data) external;
}
