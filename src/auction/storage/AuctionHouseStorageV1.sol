// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {IToken} from "../../token/IToken.sol";

contract AuctionHouseStorageV1 {
    /// @notice The metadata type of an auction
    /// @param tokenId The ERC-721 token id
    /// @param highestBid The highest bid amount
    /// @param highestBidder The address of the highest bidder
    /// @param startTime The time that the auction started
    /// @param endTime The time that the auction is scheduled to end
    /// @param settled If the auction has been settled
    struct Auction {
        uint256 tokenId;
        uint256 highestBid;
        address highestBidder;
        uint40 startTime;
        uint40 endTime;
        bool settled;
    }

    /// @notice The metadata of the current auction
    Auction public auction;

    /// @notice The ERC-721 token contract
    IToken public token;

    /// @notice The time duration of an auction
    uint256 public duration;

    /// @notice The minimum price to start an auction
    uint256 public reservePrice;

    /// @notice The minimum time left after a bid
    uint256 public timeBuffer;

    /// @notice The minimum percentage difference between two bids
    uint256 public minBidIncrementPercentage;
}
