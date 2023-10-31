// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { UUPS } from "../lib/proxy/UUPS.sol";
import { Ownable } from "../lib/utils/Ownable.sol";
import { ReentrancyGuard } from "../lib/utils/ReentrancyGuard.sol";
import { Pausable } from "../lib/utils/Pausable.sol";
import { SafeCast } from "../lib/utils/SafeCast.sol";

import { AuctionStorageV1 } from "./storage/AuctionStorageV1.sol";
import { Token } from "../token/Token.sol";
import { AuctionStorageV2 } from "./storage/AuctionStorageV2.sol";
import { Manager } from "../manager/Manager.sol";
import { IAuction } from "./IAuction.sol";
import { IWETH } from "../lib/interfaces/IWETH.sol";
import { IProtocolRewards } from "../lib/interfaces/IProtocolRewards.sol";

import { VersionedContract } from "../VersionedContract.sol";

/// @title Auction
/// @author Rohan Kulkarni & Neokry
/// @notice A DAO's auction house
/// @custom:repo github.com/ourzora/nouns-protocol
/// Modified from:
/// - NounsAuctionHouse.sol commit 2cbe6c7 - licensed under the BSD-3-Clause license.
/// - Zora V3 ReserveAuctionCoreEth module commit 795aeca - licensed under the GPL-3.0 license.
contract Auction is IAuction, VersionedContract, UUPS, Ownable, ReentrancyGuard, Pausable, AuctionStorageV1, AuctionStorageV2 {
    ///                                                          ///
    ///                          CONSTANTS                       ///
    ///                                                          ///

    /// @notice The basis points for 100%
    uint256 private constant BPS_PER_100_PERCENT = 10_000;

    /// @notice The maximum rewards percentage
    uint256 private constant MAX_FOUNDER_REWARD_BPS = 3_000;

    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    /// @notice Iniital time buffer for auction bids
    uint40 private immutable INITIAL_TIME_BUFFER = 5 minutes;

    /// @notice Min bid increment BPS
    uint8 private immutable INITIAL_MIN_BID_INCREMENT_PERCENT = 10;

    /// @notice The address of WETH
    address private immutable WETH;

    /// @notice The contract upgrade manager
    Manager private immutable manager;

    /// @notice The rewards manager
    IProtocolRewards private immutable rewardsManager;

    /// @notice The builder reward BPS as a percent of settled auction amount
    uint16 public immutable builderRewardsBPS;

    /// @notice The referral reward BPS as a percent of settled auction amount
    uint16 public immutable referralRewardsBPS;

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    /// @param _manager The contract upgrade manager address
    /// @param _rewardsManager The protocol rewards manager address
    /// @param _weth The address of WETH
    constructor(
        address _manager,
        address _rewardsManager,
        address _weth,
        uint16 _builderRewardsBPS,
        uint16 _referralRewardsBPS
    ) payable initializer {
        manager = Manager(_manager);
        rewardsManager = IProtocolRewards(_rewardsManager);
        WETH = _weth;
        builderRewardsBPS = _builderRewardsBPS;
        referralRewardsBPS = _referralRewardsBPS;
    }

    ///                                                          ///
    ///                          INITIALIZER                     ///
    ///                                                          ///

    /// @notice Initializes a DAO's auction contract
    /// @param _token The ERC-721 token address
    /// @param _founder The founder responsible for starting the first auction
    /// @param _treasury The treasury address where ETH will be sent
    /// @param _duration The duration of each auction
    /// @param _reservePrice The reserve price of each auction
    /// @param _founderRewardRecipient The address to recieve founders rewards
    /// @param _founderRewardBps The percent of rewards a founder receives in BPS for each auction
    function initialize(
        address _token,
        address _founder,
        address _treasury,
        uint256 _duration,
        uint256 _reservePrice,
        address _founderRewardRecipient,
        uint16 _founderRewardBps
    ) external initializer {
        // Ensure the caller is the contract manager
        if (msg.sender != address(manager)) revert ONLY_MANAGER();

        // Ensure the founder reward is not more than max
        if (_founderRewardBps > MAX_FOUNDER_REWARD_BPS) revert INVALID_REWARDS_BPS();

        // Ensure the recipient is set if the reward is greater than 0
        if (_founderRewardBps > 0 && _founderRewardRecipient == address(0)) revert INVALID_REWARDS_RECIPIENT();

        // Initialize the reentrancy guard
        __ReentrancyGuard_init();

        // Grant initial ownership to a founder
        __Ownable_init(_founder);

        // Pause the contract until the first auction
        __Pausable_init(true);

        // Store DAO's ERC-721 token
        token = Token(_token);

        // Store the auction house settings
        settings.duration = SafeCast.toUint40(_duration);
        settings.reservePrice = _reservePrice;
        settings.treasury = _treasury;
        settings.timeBuffer = INITIAL_TIME_BUFFER;
        settings.minBidIncrement = INITIAL_MIN_BID_INCREMENT_PERCENT;

        // Store the founder rewards settings
        founderReward.recipient = _founderRewardRecipient;
        founderReward.percentBps = _founderRewardBps;
    }

    ///                                                          ///
    ///                          CREATE BID                      ///
    ///                                                          ///

    /// @notice Creates a bid for the current token
    /// @param _tokenId The ERC-721 token id
    function createBidWithReferral(uint256 _tokenId, address _referral) external payable nonReentrant {
        currentBidReferral = _referral;
        _createBid(_tokenId);
    }

    /// @notice Creates a bid for the current token
    /// @param _tokenId The ERC-721 token id
    function createBid(uint256 _tokenId) external payable nonReentrant {
        currentBidReferral = address(0);
        _createBid(_tokenId);
    }

    /// @notice Creates a bid for the current token
    /// @param _tokenId The ERC-721 token id
    function _createBid(uint256 _tokenId) private {
        // Ensure the bid is for the current token
        if (auction.tokenId != _tokenId) {
            revert INVALID_TOKEN_ID();
        }

        // Ensure the auction is still active
        if (block.timestamp >= auction.endTime) {
            revert AUCTION_OVER();
        }

        // Cache the amount of ETH attached
        uint256 msgValue = msg.value;

        // Cache the address of the highest bidder
        address lastHighestBidder = auction.highestBidder;

        // Cache the last highest bid
        uint256 lastHighestBid = auction.highestBid;

        // Store the new highest bid
        auction.highestBid = msgValue;

        // Store the new highest bidder
        auction.highestBidder = msg.sender;

        // Used to store whether to extend the auction
        bool extend;

        // Cannot underflow as `_auction.endTime` is ensured to be greater than the current time above
        unchecked {
            // Compute whether the time remaining is less than the buffer
            extend = (auction.endTime - block.timestamp) < settings.timeBuffer;

            // If the auction should be extended
            if (extend) {
                // Update the end time with the additional time buffer
                auction.endTime = uint40(block.timestamp + settings.timeBuffer);
            }
        }

        // If this is the first bid:
        if (lastHighestBidder == address(0)) {
            // Ensure the bid meets the reserve price
            if (msgValue < settings.reservePrice) {
                revert RESERVE_PRICE_NOT_MET();
            }

            // Else this is a subsequent bid:
        } else {
            // Used to store the minimum bid required
            uint256 minBid;

            // Cannot realistically overflow
            unchecked {
                // Compute the minimum bid
                minBid = lastHighestBid + ((lastHighestBid * settings.minBidIncrement) / 100);
            }

            // Ensure the incoming bid meets the minimum
            if (msgValue < minBid) {
                revert MINIMUM_BID_NOT_MET();
            }
            // Ensure that the second bid is not also zero
            if (minBid == 0 && msgValue == 0 && lastHighestBidder != address(0)) {
                revert MINIMUM_BID_NOT_MET();
            }

            // Refund the previous bidder
            _handleOutgoingTransfer(lastHighestBidder, lastHighestBid);
        }

        emit AuctionBid(_tokenId, msg.sender, msgValue, extend, auction.endTime);
    }

    ///                                                          ///
    ///                    SETTLE & CREATE AUCTION               ///
    ///                                                          ///

    /// @notice Settles the current auction and creates the next one
    function settleCurrentAndCreateNewAuction() external nonReentrant whenNotPaused {
        _settleAuction();
        _createAuction();
    }

    /// @dev Settles the current auction
    function _settleAuction() private {
        // Get a copy of the current auction
        Auction memory _auction = auction;

        // Ensure the auction wasn't already settled
        if (auction.settled) revert AUCTION_SETTLED();

        // Ensure the auction had started
        if (_auction.startTime == 0) revert AUCTION_NOT_STARTED();

        // Ensure the auction is over
        if (block.timestamp < _auction.endTime) revert AUCTION_ACTIVE();

        // Mark the auction as settled
        auction.settled = true;

        // If a bid was placed:
        if (_auction.highestBidder != address(0)) {
            // Cache the amount of the highest bid
            uint256 highestBid = _auction.highestBid;

            // If the highest bid included ETH: Pay rewards and transfer remaining amount to the DAO treasury
            if (highestBid != 0) {
                // Calculate rewards
                RewardSplits memory split = _computeTotalRewards(currentBidReferral, highestBid, founderReward.percentBps);

                if (split.totalRewards != 0) {
                    // Deposit rewards
                    rewardsManager.depositBatch{ value: split.totalRewards }(split.recipients, split.amounts, split.reasons, "");
                }

                // Deposit remaining amount to treasury
                _handleOutgoingTransfer(settings.treasury, highestBid - split.totalRewards);
            }

            // Transfer the token to the highest bidder
            token.transferFrom(address(this), _auction.highestBidder, _auction.tokenId);

            // Else no bid was placed:
        } else {
            // Burn the token
            token.burn(_auction.tokenId);
        }

        emit AuctionSettled(_auction.tokenId, _auction.highestBidder, _auction.highestBid);
    }

    /// @dev Creates an auction for the next token
    function _createAuction() private returns (bool) {
        // Get the next token available for bidding
        try token.mint() returns (uint256 tokenId) {
            // Store the token id
            auction.tokenId = tokenId;

            // Cache the current timestamp
            uint256 startTime = block.timestamp;

            // Used to store the auction end time
            uint256 endTime;

            // Cannot realistically overflow
            unchecked {
                // Compute the auction end time
                endTime = startTime + settings.duration;
            }

            // Store the auction start and end time
            auction.startTime = uint40(startTime);
            auction.endTime = uint40(endTime);

            // Reset data from the previous auction
            auction.highestBid = 0;
            auction.highestBidder = address(0);
            auction.settled = false;

            // Reset referral from the previous auction
            currentBidReferral = address(0);

            emit AuctionCreated(tokenId, startTime, endTime);
            return true;
        } catch {
            // Pause the contract if token minting failed
            _pause();
            return false;
        }
    }

    ///                                                          ///
    ///                             PAUSE                        ///
    ///                                                          ///

    /// @notice Unpauses the auction house
    function unpause() external onlyOwner {
        _unpause();

        // If this is the first auction:
        if (!settings.launched) {
            // Mark the DAO as launched
            settings.launched = true;

            // Transfer ownership of the auction contract to the DAO
            transferOwnership(settings.treasury);

            // Transfer ownership of the token contract to the DAO
            token.onFirstAuctionStarted();

            // Start the first auction
            if (!_createAuction()) {
                // In cause of failure, revert.
                revert AUCTION_CREATE_FAILED_TO_LAUNCH();
            }
        }
        // Else if the contract was paused and the previous auction was settled:
        else if (auction.settled) {
            // Start the next auction
            _createAuction();
        }
    }

    /// @notice Pauses the auction house
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Settles the latest auction when the contract is paused
    function settleAuction() external nonReentrant whenPaused {
        _settleAuction();
    }

    ///                                                          ///
    ///                       AUCTION SETTINGS                   ///
    ///                                                          ///

    /// @notice The DAO treasury
    function treasury() external view returns (address) {
        return settings.treasury;
    }

    /// @notice The time duration of each auction
    function duration() external view returns (uint256) {
        return settings.duration;
    }

    /// @notice The reserve price of each auction
    function reservePrice() external view returns (uint256) {
        return settings.reservePrice;
    }

    /// @notice The minimum amount of time to place a bid during an active auction
    function timeBuffer() external view returns (uint256) {
        return settings.timeBuffer;
    }

    /// @notice The minimum percentage an incoming bid must raise the highest bid
    function minBidIncrement() external view returns (uint256) {
        return settings.minBidIncrement;
    }

    ///                                                          ///
    ///                       UPDATE SETTINGS                    ///
    ///                                                          ///

    /// @notice Updates the time duration of each auction
    /// @param _duration The new time duration
    function setDuration(uint256 _duration) external onlyOwner whenPaused {
        settings.duration = SafeCast.toUint40(_duration);

        emit DurationUpdated(_duration);
    }

    /// @notice Updates the reserve price of each auction
    /// @param _reservePrice The new reserve price
    function setReservePrice(uint256 _reservePrice) external onlyOwner whenPaused {
        settings.reservePrice = _reservePrice;

        emit ReservePriceUpdated(_reservePrice);
    }

    /// @notice Updates the time buffer of each auction
    /// @param _timeBuffer The new time buffer
    function setTimeBuffer(uint256 _timeBuffer) external onlyOwner whenPaused {
        settings.timeBuffer = SafeCast.toUint40(_timeBuffer);

        emit TimeBufferUpdated(_timeBuffer);
    }

    /// @notice Updates the minimum bid increment of each subsequent bid
    /// @param _percentage The new percentage
    function setMinimumBidIncrement(uint256 _percentage) external onlyOwner whenPaused {
        if (_percentage == 0) {
            revert MIN_BID_INCREMENT_1_PERCENT();
        }

        settings.minBidIncrement = SafeCast.toUint8(_percentage);

        emit MinBidIncrementPercentageUpdated(_percentage);
    }

    /// @notice Updates the founder reward recipent address
    /// @param reward The new founder reward settings
    function setFounderReward(FounderReward calldata reward) external onlyOwner whenPaused {
        // Ensure the founder reward is not more than max
        if (reward.percentBps > MAX_FOUNDER_REWARD_BPS) revert INVALID_REWARDS_BPS();

        // Ensure the recipient is set if the reward is greater than 0
        if (reward.percentBps > 0 && reward.recipient == address(0)) revert INVALID_REWARDS_RECIPIENT();

        // Update the founder reward settings
        founderReward = reward;

        emit FounderRewardUpdated(reward);
    }

    ///                                                          ///
    ///                       COMPUTE REWARDS UTIL               ///
    ///                                                          ///

    /// @notice Computes the total rewards for a bid
    /// @param _currentBidRefferal The referral for the current bid
    /// @param _finalBidAmount The final bid amount
    /// @param _founderRewardBps The reward to be paid to the founder in BPS
    function _computeTotalRewards(
        address _currentBidRefferal,
        uint256 _finalBidAmount,
        uint256 _founderRewardBps
    ) internal view returns (RewardSplits memory split) {
        // Get global builder recipient from manager
        address builderRecipient = manager.builderRewardsRecipient();

        // Calculate the total rewards percentage
        uint256 totalBPS = _founderRewardBps + referralRewardsBPS + builderRewardsBPS;

        // Verify percentage is not more than 100
        if (totalBPS >= BPS_PER_100_PERCENT) {
            revert INVALID_REWARD_TOTAL();
        }

        // Calulate total rewards
        split.totalRewards = (_finalBidAmount * totalBPS) / BPS_PER_100_PERCENT;

        // Check if founder reward is enabled
        bool hasFounderReward = _founderRewardBps > 0 && founderReward.recipient != address(0);

        // Set array size based on if founder reward is enabled
        uint256 arraySize = hasFounderReward ? 3 : 2;

        // Initialize arrays
        split.recipients = new address[](arraySize);
        split.amounts = new uint256[](arraySize);
        split.reasons = new bytes4[](arraySize);

        // Set builder reward
        split.recipients[0] = builderRecipient;
        split.amounts[0] = (_finalBidAmount * builderRewardsBPS) / BPS_PER_100_PERCENT;

        // Set referral reward
        split.recipients[1] = _currentBidRefferal != address(0) ? _currentBidRefferal : builderRecipient;
        split.amounts[1] = (_finalBidAmount * referralRewardsBPS) / BPS_PER_100_PERCENT;

        // Set founder reward if enabled
        if (hasFounderReward) {
            split.recipients[2] = founderReward.recipient;
            split.amounts[2] = (_finalBidAmount * _founderRewardBps) / BPS_PER_100_PERCENT;
        }
    }

    ///                                                          ///
    ///                        TRANSFER UTIL                     ///
    ///                                                          ///

    /// @notice Transfer ETH/WETH from the contract
    /// @param _to The recipient address
    /// @param _amount The amount transferring
    function _handleOutgoingTransfer(address _to, uint256 _amount) private {
        // Ensure the contract has enough ETH to transfer
        if (address(this).balance < _amount) revert INSOLVENT();

        // Used to store if the transfer succeeded
        bool success;

        assembly {
            // Transfer ETH to the recipient
            // Limit the call to 50,000 gas
            success := call(50000, _to, _amount, 0, 0, 0, 0)
        }

        // If the transfer failed:
        if (!success) {
            // Wrap as WETH
            IWETH(WETH).deposit{ value: _amount }();

            // Transfer WETH instead
            bool wethSuccess = IWETH(WETH).transfer(_to, _amount);

            // Ensure successful transfer
            if (!wethSuccess) {
                revert FAILING_WETH_TRANSFER();
            }
        }
    }

    ///                                                          ///
    ///                        AUCTION UPGRADE                   ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract and the new implementation is valid
    /// @dev This function is called in `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The new implementation address
    function _authorizeUpgrade(address _newImpl) internal view override onlyOwner whenPaused {
        // Ensure the new implementation is registered by the Builder DAO
        if (!manager.isRegisteredUpgrade(_getImplementation(), _newImpl)) revert INVALID_UPGRADE(_newImpl);
    }
}
