// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { IERC721 } from "../../lib/interfaces/IERC721.sol";
import { IERC721Votes } from "../../lib/interfaces/IERC721Votes.sol";
import { IManager } from "../../manager/IManager.sol";

/// @title IBaseToken
/// @author Neokry
/// @notice The external Token events, errors and functions
interface IBaseToken is IERC721, IERC721Votes {
    ///                                                          ///
    ///                           FUNCTIONS                      ///
    ///                                                          ///

    /// @notice Mints tokens to the caller and handles founder vesting
    function mint() external returns (uint256 tokenId);

    /// @notice Mints tokens to the recipient and handles founder vesting
    function mintTo(address recipient) external returns (uint256 tokenId);

    /// @notice Mints the specified amount of tokens to the recipient and handles founder vesting
    function mintBatchTo(uint256 amount, address recipient) external returns (uint256[] memory tokenIds);

    /// @notice Burns a token owned by the caller
    /// @param tokenId The ERC-721 token id
    function burn(uint256 tokenId) external;

    /// @notice The URI for a token
    /// @param tokenId The ERC-721 token id
    function tokenURI(uint256 tokenId) external view returns (string memory);

    /// @notice The URI for the contract
    function contractURI() external view returns (string memory);

    /// @notice The total supply of tokens
    function totalSupply() external view returns (uint256);

    /// @notice The token's auction house
    function auction() external view returns (address);

    /// @notice The token's metadata renderer
    function metadataRenderer() external view returns (address);

    /// @notice The owner of the token and metadata renderer
    function owner() external view returns (address);

    /// @notice Check if an address is a minter
    /// @param _minter Address to check
    function isMinter(address _minter) external view returns (bool);

    /// @notice Callback called by auction on first auction started to transfer ownership to treasury from founder
    function onFirstAuctionStarted() external;
}
