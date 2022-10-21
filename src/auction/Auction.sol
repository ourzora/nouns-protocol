// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { UUPS } from "../lib/proxy/UUPS.sol";
import { Ownable } from "../lib/utils/Ownable.sol";
import { ReentrancyGuard } from "../lib/utils/ReentrancyGuard.sol";
import { Pausable } from "../lib/utils/Pausable.sol";
import { SafeCast } from "../lib/utils/SafeCast.sol";

import { AuctionStorageV1 } from "./storage/AuctionStorageV1.sol";
import { Token } from "../token/Token.sol";
import { IManager } from "../manager/IManager.sol";
import { IAuction } from "./IAuction.sol";
import { IWETH } from "../lib/interfaces/IWETH.sol";

/// @title Auction
/// @author Rohan Kulkarni
/// @notice A DAO's auction house
/// Modified from:
/// - NounsAuctionHouse.sol commit 2cbe6c7 - licensed under the BSD-3-Clause license.
/// - Zora V3 ReserveAuctionCoreEth module commit 795aeca - licensed under the GPL-3.0 license.
contract Auction is IAuction, UUPS, Ownable, ReentrancyGuard, Pausable, AuctionStorageV1 {
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
    IManager private immutable manager;

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    /// @param _manager The contract upgrade manager address
    /// @param _weth The address of WETH
    constructor(address _manager, address _weth) payable initializer {
        manager = IManager(_manager);
        WETH = _weth;
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
    function initialize(
        address _token,
        address _founder,
        address _treasury,
        uint256 _duration,
        uint256 _reservePrice
    ) external initializer {
        // Ensure the caller is the contract manager
        if (msg.sender != address(manager)) revert ONLY_MANAGER();

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
    }

    ///                                                          ///
    ///                          CREATE BID                      ///
    ///                                                          ///

    /// @notice Creates a bid for the current token
    /// @param _tokenId The ERC-721 token id
    function createBid(uint256 _tokenId) external payable nonReentrant {
        // Ensure the bid is for the current token
        if (auction.tokenId != _tokenId) revert INVALID_TOKEN_ID();

        // Ensure the auction is still active
        if (block.timestamp >= auction.endTime) revert AUCTION_OVER();

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
            if (msgValue < settings.reservePrice) revert RESERVE_PRICE_NOT_MET();

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
            if (msgValue < minBid || minBid == lastHighestBid) revert MINIMUM_BID_NOT_MET();

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

            // If the highest bid included ETH: Transfer it to the DAO treasury
            if (highestBid != 0) _handleOutgoingTransfer(settings.treasury, highestBid);

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
        settings.minBidIncrement = SafeCast.toUint8(_percentage);

        emit MinBidIncrementPercentageUpdated(_percentage);
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
