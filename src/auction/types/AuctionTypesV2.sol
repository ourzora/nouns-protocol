// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title AuctionTypesV2
/// @author Neokry
/// @notice The Auction custom data types
contract AuctionTypesV2 {
    /// @notice The settings type
    /// @param recipient The DAO founder collecting protocol rewards
    /// @param percentBps The rewards to be paid to the DAO founder in BPS
    struct FounderReward {
        address recipient;
        uint16 percentBps;
    }
}
