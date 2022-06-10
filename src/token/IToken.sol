// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {IVotesUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/utils/IVotesUpgradeable.sol";

import {IMetadataRenderer} from "./metadata/IMetadataRenderer.sol";

interface IToken is IERC721Upgradeable, IVotesUpgradeable, IMetadataRenderer {
    function mint() external returns (uint256);

    function burn(uint256 tokenId) external;

    function setMinter(address minter) external;

    function setFoundersDAO(address foundersDAO) external;

    function totalCount() external view returns (uint256);
}
