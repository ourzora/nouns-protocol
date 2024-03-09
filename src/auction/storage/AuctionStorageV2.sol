// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { AuctionTypesV2 } from "../types/AuctionTypesV2.sol";

contract AuctionStorageV2 is AuctionTypesV2 {
    /// @notice The referral for the current auction bid
    address public currentBidReferral;

    /// @notice The founder reward settings
    FounderReward public founderReward;
}
