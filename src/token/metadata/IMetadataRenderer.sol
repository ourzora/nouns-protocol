// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface IMetadataRenderer {
    function contractURI() external view returns (string memory);

    function tokenURI(uint256) external view returns (string memory);
}
