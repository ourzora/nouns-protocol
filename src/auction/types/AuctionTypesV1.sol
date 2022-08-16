// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

// TODO IToken where treasury is and move treasury before reserve price
contract AuctionTypesV1 {
    struct Settings {
        address treasury;
        uint40 duration;
        uint40 timeBuffer;
        uint8 minBidIncrement;
        uint256 reservePrice;
    }

    struct Auction {
        uint256 tokenId;
        uint256 highestBid;
        address highestBidder;
        uint40 startTime;
        uint40 endTime;
        bool settled;
    }
}
