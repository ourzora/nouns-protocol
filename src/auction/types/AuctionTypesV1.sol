// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title AuctionTypesV1
/// @author Rohan Kulkarni
/// @notice The Auction custom data types
contract AuctionTypesV1 {
    /// @notice The settings type
    /// @param treasury The DAO treasury
    /// @param duration The time duration of each auction
    /// @param timeBuffer The minimum time to place a bid
    /// @param minBidIncrement The minimum percentage an incoming bid must raise the highest bid
    /// @param launched If the first auction has been kicked off
    /// @param reservePrice The reserve price of each auction
    struct Settings {
        address treasury;
        uint40 duration;
        uint40 timeBuffer;
        uint8 minBidIncrement;
        bool launched;
        uint256 reservePrice;
    }

    /// @notice The auction type
    /// @param tokenId The ERC-721 token id
    /// @param highestBid The highest amount of ETH raised
    /// @param highestBidder The leading bidder
    /// @param startTime The timestamp the auction starts
    /// @param endTime The timestamp the auction ends
    /// @param settled If the auction has been settled
    struct Auction {
        uint256 tokenId;
        uint256 highestBid;
        address highestBidder;
        uint40 startTime;
        uint40 endTime;
        bool settled;
    }
}
