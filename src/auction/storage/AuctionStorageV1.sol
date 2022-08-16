// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {Token} from "../../token/Token.sol";
import {AuctionTypesV1} from "../types/AuctionTypesV1.sol";

/// @title AuctionStorageV1
/// @author Rohan Kulkarni
/// @notice The
contract AuctionStorageV1 is AuctionTypesV1 {
    /// @notice The ERC-721 token contract
    Token public token;

    /// @notice The DAO auction house settings
    Settings public settings;

    /// @notice The current auction state
    Auction public auction;
}
