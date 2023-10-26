// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title ManagerTypesV2
/// @author Neokry
/// @notice The external Base Metadata errors and functions
interface ManagerTypesV2 {
    /// @notice Config for protocol rewards
    struct RewardConfig {
        //// @notice Address to send Builder DAO rewards to
        address builderRecipient;
        //// @notice Percentage of final bid amount in BPS claimable by the bid referral
        uint256 referralBps;
        //// @notice Percentage of final bid amount in BPS claimable by BuilderDAO
        uint256 builderBps;
    }
}
