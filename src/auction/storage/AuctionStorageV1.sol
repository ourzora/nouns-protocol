// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {IToken} from "../../token/IToken.sol";
import {IAuction} from "../IAuction.sol";

contract AuctionStorageV1 {
    /// @notice The ERC-721 token contract
    IToken public token;

    /// @notice The metadata of the latest auction
    IAuction.Auction public auction;

    /// @notice The metadata of the auction house
    IAuction.House public house;
}
