// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { EIP712 } from "../lib/utils/EIP712.sol";
import { ECDSA } from "../lib/utils/ECDSA.sol";
import { Ownable } from "../lib/utils/Ownable.sol";
import { IProtocolRewards } from "./interfaces/IProtocolRewards.sol";

/// @title ProtocolRewards
/// @notice Manager of deposits & withdrawals for protocol rewards
contract ProtocolRewards is IProtocolRewards, EIP712 {
    ///                                                          ///
    ///                            CONSTANTS                     ///
    ///                                                          ///

    /// @notice The EIP-712 typehash for gasless withdraws
    bytes32 public constant WITHDRAW_TYPEHASH = keccak256("Withdraw(address from,address to,uint256 amount,uint256 nonce,uint256 deadline)");

    ///                                                          ///
    ///                            IMMUTABLES                    ///
    ///                                                          ///

    /// @notice Manager contract
    address immutable manager;

    ///                                                          ///
    ///                            STORAGE                       ///
    ///                                                          ///

    /// @notice An account's balance
    mapping(address => uint256) public balanceOf;

    /// @notice Configuration for the protocol rewards
    RewardConfig public config;

    ///                                                          ///
    ///                            MODIFIERS                     ///
    ///                                                          ///

    /// @notice Checks if the current caller is the owner of the manager contract
    modifier onlyManagerOwner() {
        if (!_isManagerOwner()) {
            revert ONLY_MANAGER_OWNER();
        }
        _;
    }

    ///                                                          ///
    ///                            CONSTRUCTOR                   ///
    ///                                                          ///

    constructor(address _manager, address _builderRewardRecipient) payable initializer {
        manager = _manager;
        config.builderRewardRecipient = _builderRewardRecipient;
        __EIP712_init("ProtocolRewards", "1");
    }

    ///                                                          ///
    ///                            SUPPLY                        ///
    ///                                                          ///

    /// @notice The total amount of ETH held in the contract
    function totalSupply() external view returns (uint256) {
        return address(this).balance;
    }

    ///                                                          ///
    ///                            CONFIGURATION                 ///
    ///                                                          ///

    /// @notice Function to set the reward percentages
    /// @param referralRewardBPS The reward to be paid to the referrer in BPS
    /// @param builderRewardBPS The reward to be paid to Build DAO in BPS
    function setRewardPercentages(uint256 referralRewardBPS, uint256 builderRewardBPS) external onlyManagerOwner {
        config.referralRewardBPS = referralRewardBPS;
        config.builderRewardBPS = builderRewardBPS;
    }

    /// @notice Function to set the builder reward recipient
    /// @param builderRewardRecipient The address to send Builder DAO rewards to
    function setBuilderRewardRecipient(address builderRewardRecipient) external onlyManagerOwner {
        config.builderRewardRecipient = builderRewardRecipient;
    }

    ///                                                          ///
    ///                            DEPOSIT                       ///
    ///                                                          ///

    /// @notice Generic function to deposit ETH for a recipient, with an optional comment
    /// @param to Address to deposit to
    /// @param to Reason system reason for deposit (used for indexing)
    /// @param comment Optional comment as reason for deposit
    function deposit(
        address to,
        bytes4 reason,
        string calldata comment
    ) external payable {
        // Cannot deposit to 0 address
        if (to == address(0)) {
            revert ADDRESS_ZERO();
        }

        balanceOf[to] += msg.value;

        emit Deposit(msg.sender, to, reason, msg.value, comment);
    }

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
    ) external payable {
        // Cache length of recipients array
        uint256 numRecipients = recipients.length;

        // Verify array lengths match
        if (numRecipients != amounts.length || numRecipients != reasons.length) {
            revert ARRAY_LENGTH_MISMATCH();
        }

        uint256 expectedTotalValue;

        // Calculate expected total value
        for (uint256 i; i < numRecipients; ) {
            expectedTotalValue += amounts[i];

            unchecked {
                ++i;
            }
        }

        // Verify sent value matches expected total value
        if (msg.value != expectedTotalValue) {
            revert INVALID_DEPOSIT();
        }

        address currentRecipient;
        uint256 currentAmount;

        // Deposit for each recipient
        for (uint256 i; i < numRecipients; ) {
            currentRecipient = recipients[i];
            currentAmount = amounts[i];

            // Cannot deposit to 0 address
            if (currentRecipient == address(0)) {
                revert ADDRESS_ZERO();
            }

            // Deposit for recipient
            balanceOf[currentRecipient] += currentAmount;

            emit Deposit(msg.sender, currentRecipient, reasons[i], currentAmount, comment);

            unchecked {
                ++i;
            }
        }
    }

    ///                                                          ///
    ///                            REWARDS                       ///
    ///                                                          ///

    /// @notice Computes the total rewards for a bid
    /// @param finalBidAmount The final bid amount
    /// @param founderRewardBPS The reward to be paid to the founder in BPS
    function computeTotalRewards(uint256 finalBidAmount, uint256 founderRewardBPS) external view returns (RewardSplits memory split) {
        // Cache values from storage
        uint256 referralBPSCached = config.referralRewardBPS;
        uint256 builderBPSCached = config.referralRewardBPS;

        // Calculate the total rewards percentage
        uint256 totalBPS = founderRewardBPS + referralBPSCached + builderBPSCached;

        // Verify percentage is not more than 100
        if (totalBPS >= 10_000) {
            revert INVALID_PERCENTAGES();
        }

        // Calulate total rewards
        split.totalRewards = (finalBidAmount * totalBPS) / 10_000;

        // Calculate reward splits
        split.founderReward = (finalBidAmount * founderRewardBPS) / 10_000;
        split.refferalReward = (finalBidAmount * referralBPSCached) / 10_000;
        split.builderReward = (finalBidAmount * builderBPSCached) / 10_000;
    }

    /// @notice Used by Auction contracts to deposit protocol rewards
    /// @param founder Creator for NFT rewards
    /// @param founderReward Creator for NFT rewards
    /// @param referral Creator reward amount
    /// @param referralReward Mint referral user
    /// @param builderReward Mint referral user
    function depositRewards(
        address founder,
        uint256 founderReward,
        address referral,
        uint256 referralReward,
        uint256 builderReward
    ) external payable {
        // Validate deposit amount
        if (msg.value != (founderReward + referralReward + builderReward)) {
            revert INVALID_DEPOSIT();
        }

        // Cache builder reward recipient from storage
        address cachedBuilderRecipent = config.builderRewardRecipient;

        // Set referral to builder if not set
        if (referral == address(0)) {
            referral = cachedBuilderRecipent;
        }

        // Set claim amounts for each reward
        unchecked {
            if (founder != address(0)) {
                balanceOf[founder] += founderReward;
            }
            if (referral != address(0)) {
                balanceOf[referral] += referralReward;
            }
            if (cachedBuilderRecipent != address(0)) {
                balanceOf[cachedBuilderRecipent] += builderReward;
            }
        }

        emit RewardsDeposit(founder, referral, cachedBuilderRecipent, msg.sender, founderReward, referralReward, builderReward);
    }

    ///                                                          ///
    ///                            WITHDRAW                      ///
    ///                                                          ///

    /// @notice Withdraw protocol rewards
    /// @param to Withdraws from msg.sender to this address
    /// @param amount Amount to withdraw (0 for total balance)
    function withdraw(address to, uint256 amount) external {
        // Cannot withdraw to 0 address
        if (to == address(0)) {
            revert ADDRESS_ZERO();
        }

        address owner = msg.sender;

        // Cannot withdraw more than balance
        if (amount > balanceOf[owner]) {
            revert INVALID_WITHDRAW();
        }

        // Withdraw full balance if amount is 0
        if (amount == 0) {
            amount = balanceOf[owner];
        }

        balanceOf[owner] -= amount;

        emit Withdraw(owner, to, amount);

        (bool success, ) = to.call{ value: amount }("");

        // Revert if transfer fails
        if (!success) {
            revert TRANSFER_FAILED();
        }
    }

    /// @notice Withdraw rewards on behalf of an address
    /// @param to The address to withdraw for
    /// @param amount The amount to withdraw (0 for total balance)
    function withdrawFor(address to, uint256 amount) external {
        // Cannot withdraw to 0 address
        if (to == address(0)) {
            revert ADDRESS_ZERO();
        }

        // Cannot withdraw more than balance
        if (amount > balanceOf[to]) {
            revert INVALID_WITHDRAW();
        }

        // Withdraw full balance if amount is 0
        if (amount == 0) {
            amount = balanceOf[to];
        }

        balanceOf[to] -= amount;

        emit Withdraw(to, to, amount);

        (bool success, ) = to.call{ value: amount }("");

        // Revert if transfer fails
        if (!success) {
            revert TRANSFER_FAILED();
        }
    }

    /// @notice Execute a withdraw of protocol rewards via signature
    /// @param from Withdraw from this address
    /// @param to Withdraw to this address
    /// @param amount Amount to withdraw (0 for total balance)
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
    ) external {
        // Cannot withdraw if signature has expired
        if (block.timestamp > deadline) {
            revert SIGNATURE_DEADLINE_EXPIRED();
        }

        bytes32 withdrawHash;

        // Generate the hashed withdraw message
        unchecked {
            withdrawHash = keccak256(abi.encode(WITHDRAW_TYPEHASH, from, to, amount, nonces[from]++, deadline));
        }

        bytes32 digest = ECDSA.toTypedDataHash(DOMAIN_SEPARATOR(), withdrawHash);

        address recoveredAddress = ecrecover(digest, v, r, s);

        // Verify signature is valid
        if (recoveredAddress == address(0) || recoveredAddress != from) {
            revert INVALID_SIGNATURE();
        }

        // Cannot withdraw to 0 address
        if (to == address(0)) {
            revert ADDRESS_ZERO();
        }

        // Cannot withdraw more than balance
        if (amount > balanceOf[from]) {
            revert INVALID_WITHDRAW();
        }

        // Withdraw full balance if amount is 0
        if (amount == 0) {
            amount = balanceOf[from];
        }

        balanceOf[from] -= amount;

        emit Withdraw(from, to, amount);

        (bool success, ) = to.call{ value: amount }("");

        // Revert if transfer fails
        if (!success) {
            revert TRANSFER_FAILED();
        }
    }

    ///                                                          ///
    ///                            Ownership                     ///
    ///                                                          ///

    function _isManagerOwner() internal view returns (bool) {
        return msg.sender == Ownable(manager).owner();
    }
}