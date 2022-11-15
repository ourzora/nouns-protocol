// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { IUUPS } from "../lib/interfaces/IUUPS.sol";
import { IERC721Votes } from "../lib/interfaces/IERC721Votes.sol";
import { IManager } from "../manager/IManager.sol";
import { TokenTypesV1 } from "./types/TokenTypesV1.sol";

/// @title IToken
/// @author Rohan Kulkarni
/// @notice The external Token events, errors and functions
interface IToken is IUUPS, IERC721Votes, TokenTypesV1 {
    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    /// @notice Emitted when a token is scheduled to be allocated
    /// @param baseTokenId The
    /// @param founderId The founder's id
    /// @param founder The founder's vesting details
    event MintScheduled(uint256 baseTokenId, uint256 founderId, Founder founder);

    /// @notice Emitted when a token allocation is unscheduled (removed)
    /// @param baseTokenId The token ID % 100
    /// @param founderId The founder's id
    /// @param founder The founder's vesting details
    event MintUnscheduled(uint256 baseTokenId, uint256 founderId, Founder founder);

    /// @notice Emitted when a tokens founders are deleted from storage
    /// @param newFounders the list of founders
    event FounderAllocationsCleared(IManager.FounderParams[] newFounders);

    ///                                                          ///
    ///                            ERRORS                        ///
    ///                                                          ///

    /// @dev Reverts if the founder ownership exceeds 100 percent
    error INVALID_FOUNDER_OWNERSHIP();

    /// @dev Reverts if the caller was not the auction contract
    error ONLY_AUCTION();

    /// @dev Reverts if no metadata was generated upon mint
    error NO_METADATA_GENERATED();

    /// @dev Reverts if the caller was not the contract manager
    error ONLY_MANAGER();

    ///                                                          ///
    ///                           FUNCTIONS                      ///
    ///                                                          ///

    /// @notice Initializes a DAO's ERC-721 token
    /// @param founders The founding members to receive vesting allocations
    /// @param initStrings The encoded token and metadata initialization strings
    /// @param metadataRenderer The token's metadata renderer
    /// @param auction The token's auction house
    function initialize(
        IManager.FounderParams[] calldata founders,
        bytes calldata initStrings,
        address metadataRenderer,
        address auction,
        address initialOwner
    ) external;

    /// @notice Mints tokens to the auction house for bidding and handles founder vesting
    function mint() external returns (uint256 tokenId);

    /// @notice Burns a token that did not see any bids
    /// @param tokenId The ERC-721 token id
    function burn(uint256 tokenId) external;

    /// @notice The URI for a token
    /// @param tokenId The ERC-721 token id
    function tokenURI(uint256 tokenId) external view returns (string memory);

    /// @notice The URI for the contract
    function contractURI() external view returns (string memory);

    /// @notice The number of founders
    function totalFounders() external view returns (uint256);

    /// @notice The founders total percent ownership
    function totalFounderOwnership() external view returns (uint256);

    /// @notice The vesting details of a founder
    /// @param founderId The founder id
    function getFounder(uint256 founderId) external view returns (Founder memory);

    /// @notice The vesting details of all founders
    function getFounders() external view returns (Founder[] memory);

    /// @notice Update the list of allocation owners
    /// @param newFounders the full list of FounderParam structs
    function updateFounders(IManager.FounderParams[] calldata newFounders) external;                                                         
       

    /// @notice The founder scheduled to receive the given token id
    /// NOTE: If a founder is returned, there's no guarantee they'll receive the token as vesting expiration is not considered
    /// @param tokenId The ERC-721 token id
    function getScheduledRecipient(uint256 tokenId) external view returns (Founder memory);

    /// @notice The total supply of tokens
    function totalSupply() external view returns (uint256);

    /// @notice The token's auction house
    function auction() external view returns (address);

    /// @notice The token's metadata renderer
    function metadataRenderer() external view returns (address);

    /// @notice The owner of the token and metadata renderer
    function owner() external view returns (address);

    /// @notice Callback called by auction on first auction started to transfer ownership to treasury from founder
    function onFirstAuctionStarted() external;
}
