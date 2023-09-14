// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title IProtocolRewards
/// @notice The interface for deposits & withdrawals for Protocol Rewards
interface IProtocolRewards {
    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    /// @notice Rewards Deposit Event
    /// @param founder Creator for NFT rewards
    /// @param bidReferral Mint referral user
    /// @param builder First minter reward recipient
    /// @param from The caller of the deposit
    /// @param bidReferralReward Creator reward amount
    /// @param builderReward Creator referral reward
    event RewardsDeposit(
        address indexed founder,
        address indexed bidReferral,
        address builder,
        address from,
        uint256 founderReward,
        uint256 bidReferralReward,
        uint256 builderReward
    );

    /// @notice Deposit Event
    /// @param from From user
    /// @param to To user (within contract)
    /// @param reason Optional bytes4 reason for indexing
    /// @param amount Amount of deposit
    /// @param comment Optional user comment
    event Deposit(address indexed from, address indexed to, bytes4 indexed reason, uint256 amount, string comment);

    /// @notice Withdraw Event
    /// @param from From user
    /// @param to To user (within contract)
    /// @param amount Amount of deposit
    event Withdraw(address indexed from, address indexed to, uint256 amount);

    ///                                                          ///
    ///                            ERRORS                        ///
    ///                                                          ///

    /// @notice Invalid percentages
    error INVALID_PERCENTAGES();

    /// @notice Function argument array length mismatch
    error ARRAY_LENGTH_MISMATCH();

    /// @notice Invalid deposit
    error INVALID_DEPOSIT();

    /// @notice Invalid withdraw
    error INVALID_WITHDRAW();

    /// @notice Signature for withdraw is too old and has expired
    error SIGNATURE_DEADLINE_EXPIRED();

    /// @notice Low-level ETH transfer has failed
    error TRANSFER_FAILED();

    /// @notice Caller is not managers owner
    error ONLY_MANAGER_OWNER();

    ///                                                          ///
    ///                            STRUCTS                       ///
    ///                                                          ///

    /// @notice Config for protocol rewards
    struct RewardConfig {
        //// @notice Address to send Builder DAO rewards to
        address builderRewardRecipient;
        //// @notice Percentage of final bid amount in BPS claimable by the bid referral
        uint256 referralRewardBPS;
        //// @notice Percentage of final bid amount in BPS claimable by BuilderDAO
        uint256 builderRewardBPS;
    }

    struct RewardSplits {
        //// @notice Total rewards amount
        uint256 totalRewards;
        //// @notice Founder rewards amount
        uint256 founderReward;
        //// @notice Bid referral rewards amount
        uint256 refferalReward;
        //// @notice BuilderDAO rewards amount
        uint256 builderReward;
    }

    ///                                                          ///
    ///                            FUNCTIONS                     ///
    ///                                                          ///

    /// @notice Generic function to deposit ETH for a recipient, with an optional comment
    /// @param to Address to deposit to
    /// @param why Reason system reason for deposit (used for indexing)
    /// @param comment Optional comment as reason for deposit
    function deposit(
        address to,
        bytes4 why,
        string calldata comment
    ) external payable;

    /// @notice Generic function to deposit ETH for multiple recipients, with an optional comment
    /// @param recipients recipients to send the amount to, array aligns with amounts
    /// @param amounts amounts to send to each recipient, array aligns with recipients
    /// @param reasons optional bytes4 hash for indexing
    /// @param comment Optional comment to include with mint
    function depositBatch(
        address[] calldata recipients,
        uint256[] calldata amounts,
        bytes4[] calldata reasons,
        string calldata comment
    ) external payable;

    /// @notice Computes the total rewards given a bid amount and founders reward percentage
    /// @param finalBidAmount Final bid amount
    /// @param founderRewardBPS Percentage of final bid amount in BPS claimable by the founder
    function computeTotalRewards(uint256 finalBidAmount, uint256 founderRewardBPS) external returns (RewardSplits memory split);

    /// @notice Used by Auction contracts to deposit protocol rewards
    /// @param founder Deployer for founder rewards
    /// @param founderReward Founder reward amount
    /// @param referral Bid referral user
    /// @param referralReward Bid referral reward amount
    /// @param builderReward BuilderDAO reward amount
    function depositRewards(
        address founder,
        uint256 founderReward,
        address referral,
        uint256 referralReward,
        uint256 builderReward
    ) external payable;

    /// @notice Withdraw protocol rewards
    /// @param to Withdraws from msg.sender to this address
    /// @param amount amount to withdraw
    function withdraw(address to, uint256 amount) external;

    /// @notice Execute a withdraw of protocol rewards via signature
    /// @param from Withdraw from this address
    /// @param to Withdraw to this address
    /// @param amount Amount to withdraw
    /// @param deadline Deadline for the signature to be valid
    /// @param v V component of signature
    /// @param r R component of signature
    /// @param s S component of signature
    function withdrawWithSig(
        address from,
        address to,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}
