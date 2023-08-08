// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { IBaseToken } from "../../token/interfaces/IBaseToken.sol";
import { AuctionTypesV1 } from "../types/AuctionTypesV1.sol";

/// @title AuctionStorageV1
/// @author Rohan Kulkarni
/// @notice The Auction storage contract
contract AuctionStorageV1 is AuctionTypesV1 {
    /// @notice The auction settings
    Settings internal settings;

    /// @notice The ERC-721 token
    IBaseToken public token;

    /// @notice The state of the current auction
    Auction public auction;
}
