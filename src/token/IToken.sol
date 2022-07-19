// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {IMetadataRenderer} from "./metadata/IMetadataRenderer.sol";
import {IUpgradeManager} from "../upgrade/IUpgradeManager.sol";

interface IToken {
    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function initialize(
        bytes calldata init,
        address metadataRenderer,
        address foundersDAO,
        uint256 foundersMaxAllocation,
        uint256 foundersAllocationFrequency,
        address auction
    ) external;

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    struct Founders {
        address DAO;
        uint32 maxAllocation;
        uint32 allocationFrequency;
        uint32 currentAllocation;
    }

    function founders() external view returns (Founders calldata);

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function totalSupply() external view returns (uint256);

    function auction() external view returns (address);

    function mint() external returns (uint256);

    function burn(uint256 tokenId) external;

    function setAuction(address auction) external;

    function setFoundersDAO(address foundersDAO) external;

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function metadataRenderer() external view returns (IMetadataRenderer);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function contractURI() external view returns (string memory);

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function balanceOf(address owner) external view returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function approve(address to, uint256 tokenId) external;

    function setApprovalForAll(address operator, bool approved) external;

    function isApprovedForAll(address owner, address operator) external view returns (bool);

    function getApproved(uint256 tokenId) external view returns (address);

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function owner() external view returns (address);

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function getVotes(address account) external view returns (uint256);

    function getPastVotes(address account, uint256 blockNumber) external view returns (uint256);

    function getPastTotalSupply(uint256 blockNumber) external view returns (uint256);

    function autoDelegate(address user) external;

    function delegates(address account) external view returns (address);

    function delegate(address delegatee) external;

    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function nonces(address owner) external view returns (uint256);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function upgradeManager() external view returns (IUpgradeManager);

    function upgradeTo(address newImplementation) external;

    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
}
