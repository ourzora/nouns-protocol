// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

contract AuctionStorageV2 {
    /// @notice The referral for the current auction bid
    address public currentBidReferral;

    /// @notice The DAO founder collecting protocol rewards
    address public founderRewardRecipient;

    /// @notice The rewards to be paid to the DAO founder in BPS
    uint256 public founderRewardBPS;
}
