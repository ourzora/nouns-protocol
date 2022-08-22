// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {IManager} from "../manager/IManager.sol";
import {INounsMetadata} from "./metadata/INounsMetadata.sol";

interface IToken {
    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    error ONLY_OWNER();

    error ONLY_AUCTION();

    error NO_METADATA_GENERATED();

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function initialize(
        IManager.FounderParams[] calldata founders,
        bytes calldata tokenInitStrings,
        address metadataRenderer,
        address auction
    ) external;

    // function metadataRenderer() external view returns (INounsMetadata);

    // function auction() external view returns (address);

    // function totalSupply() external view returns (uint256);

    // function name() external view returns (string memory);

    // function symbol() external view returns (string memory);

    // function contractURI() external view returns (string memory);

    // function tokenURI(uint256 tokenId) external view returns (string memory);

    // function balanceOf(address owner) external view returns (uint256);

    // function ownerOf(uint256 tokenId) external view returns (address);

    // function isApprovedForAll(address owner, address operator) external view returns (bool);

    // function getApproved(uint256 tokenId) external view returns (address);

    // function getVotes(address account) external view returns (uint256);

    // function getPastVotes(address account, uint256 timestamp) external view returns (uint256);

    // function delegates(address account) external view returns (address);

    // function nonces(address owner) external view returns (uint256);

    // function DOMAIN_SEPARATOR() external view returns (bytes32);

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    // function getVotes(address user) external view returns (uint256);

    // function getPastVotes(address user, uint256 timestamp) external view returns (uint256);

    // function delegates(address _user) external view returns (address);

    // function delegate(address to) external;

    // function delegateBySig(
    //     address to,
    //     uint256 nonce,
    //     uint256 expiry,
    //     uint8 v,
    //     bytes32 r,
    //     bytes32 s
    // ) external;

    // function mint() external returns (uint256);

    // function burn(uint256 tokenId) external;

    // function approve(address to, uint256 tokenId) external;

    // function setApprovalForAll(address operator, bool approved) external;

    // function safeTransferFrom(
    //     address from,
    //     address to,
    //     uint256 tokenId,
    //     bytes calldata data
    // ) external;

    // function safeTransferFrom(
    //     address from,
    //     address to,
    //     uint256 tokenId
    // ) external;

    // function transferFrom(
    //     address from,
    //     address to,
    //     uint256 tokenId
    // ) external;
}
