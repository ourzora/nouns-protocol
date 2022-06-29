// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {IToken} from "../../token/IToken.sol";
import {IAuction} from "../IAuction.sol";

contract AuctionStorageV1 {
    /// @notice The ERC-721 token contract
    IToken public token;

    /// @notice The metadata of the current auction
    IAuction.Auction public auction;

    /// @notice The address of the treasury
    address public treasury;

    /// @notice The time duration of an auction
    uint256 public duration;

    /// @notice The minimum price to start an auction
    uint256 public reservePrice;

    /// @notice The minimum time left after a bid
    uint256 public timeBuffer;

    /// @notice The minimum percentage difference between two bids
    uint256 public minBidIncrementPercentage;
}
