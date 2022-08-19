// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {UUPS} from "../lib/proxy/UUPS.sol";
import {Ownable} from "../lib/utils/Ownable.sol";
import {ReentrancyGuard} from "../lib/utils/ReentrancyGuard.sol";
import {Pausable} from "../lib/utils/Pausable.sol";
import {Cast} from "../lib/utils/Cast.sol";

import {AuctionStorageV1} from "./storage/AuctionStorageV1.sol";
import {Token} from "../token/Token.sol";
import {IToken} from "../token/IToken.sol";
import {IAuction} from "./IAuction.sol";
import {ITimelock} from "../governance/timelock/ITimelock.sol";
import {IERC20} from "../lib/interfaces/IERC20.sol";
import {IWETH} from "../lib/interfaces/IWETH.sol";

import {IManager} from "../manager/IManager.sol";

/// @title Auction
/// @author Rohan Kulkarni
/// @notice This contract is
contract Auction is IAuction, UUPS, Ownable, ReentrancyGuard, Pausable, AuctionStorageV1 {
    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    /// @notice The address of WETH
    IWETH private immutable weth;

    /// @notice The contract upgrade manager
    IManager private immutable manager;

    function getTimelock() internal returns (address payable) {
        (, , ITimelock timelock,) = manager.getAddresses(address(token));
        return payable(address(timelock));
    }

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    /// @param _manager The address of the contract upgrade manager
    /// @param _weth The address of WETH
    constructor(IManager _manager, IWETH _weth) payable initializer {
        manager = _manager;
        weth = _weth;
    }

    ///                                                          ///
    ///                          INITIALIZER                     ///
    ///                                                          ///

    /// @notice Initializes a DAO's auction house
    /// @param _token The ERC-721 token address
    /// @param _founder The founder responsible for starting the first auction
    /// @param _duration The duration of each auction
    /// @param _reservePrice The reserve price of each auction
    function initialize(
        IToken _token,
        address _founder,
        uint256 _duration,
        uint256 _reservePrice
    ) external initializer {
        // Initialize the reentrancy guard
        __ReentrancyGuard_init();

        // Grant initial ownership to a founder to unpause the auction house when ready
        __Ownable_init(_founder);

        // Pause the contract until the first auction is ready to begin
        __Pausable_init(true);

        // Store the address of the ERC-721 token that will be bid on
        token = Token(address(_token));

        // Store the auction house settings
        settings.duration = Cast.toUint40(_duration);
        settings.reservePrice = _reservePrice;
        settings.timeBuffer = 5 minutes;
        settings.minBidIncrement = 10;
    }

    ///                                                          ///
    ///                          CREATE BID                      ///
    ///                                                          ///

    /// @notice Creates a bid for the current token
    /// @param _tokenId The ERC-721 token id
    function createBid(uint256 _tokenId) external payable nonReentrant {
        // Get the current auction in memory
        Auction memory _auction = auction;

        // Ensure the bid is for the right token id
        if (_auction.tokenId != _tokenId) revert INVALID_TOKEN_ID();

        // Ensure the auction is still active
        if (block.timestamp >= _auction.endTime) revert AUCTION_OVER();

        // Cache the address of the highest bidder
        address highestBidder = _auction.highestBidder;

        // If this is the first bid:
        if (highestBidder == address(0)) {
            // Ensure the bid meets the reserve price
            if (msg.value < settings.reservePrice) revert RESERVE_PRICE_NOT_MET();

            // Else for a subsequent bid:
        } else {
            // Cache the amount of the previous bid
            uint256 prevBid = _auction.highestBid;

            // Used to store the minimum amount required to place the current bid
            uint256 currentBidMin;

            // Compute the minimum amount
            unchecked {
                currentBidMin = prevBid + ((prevBid * settings.minBidIncrement) / 100);
            }

            // Ensure the bid meets the amount
            if (msg.value < currentBidMin) revert MINIMUM_BID_NOT_MET();

            // Refund the previous bidder
            _handleOutgoingTransfer(highestBidder, prevBid);
        }

        // Store the attached amount of ETH as the new highest bid
        auction.highestBid = msg.value;

        // Store the caller as the new highest bidder
        auction.highestBidder = msg.sender;

        // Used to store if the auction will be extended
        bool extend;

        // Cannot underflow as the end time is ensured to be greater than the current time
        unchecked {
            // Compute whether the bid was placed within the time buffer of the auction end
            extend = (_auction.endTime - block.timestamp) < settings.timeBuffer;
        }

        // If the auction is valid to extend:
        if (extend) {
            // Cannot realistically overflow
            unchecked {
                // Add the time buffer to the auction's previous end time
                auction.endTime = _auction.endTime = uint40(block.timestamp + settings.timeBuffer);
            }
        }

        emit AuctionBid(_tokenId, msg.sender, msg.value, extend, _auction.endTime);
    }

    ///                                                          ///
    ///                     SETTLE & CREATE AUCTION              ///
    ///                                                          ///

    /// @notice Settles the current auction and creates the next one
    function settleCurrentAndCreateNewAuction() external nonReentrant whenNotPaused {
        _settleAuction();
        _createAuction();
    }

    /// @dev Settles the current auction
    function _settleAuction() private {
        // Get the current auction in memory
        Auction memory _auction = auction;

        // Ensure the auction began
        if (_auction.startTime == 0) revert AUCTION_NOT_STARTED();

        // Ensure the auction ended
        if (block.timestamp < _auction.endTime) revert AUCTION_NOT_OVER();

        // Ensure the auction was not already settled
        if (auction.settled) revert AUCTION_SETTLED();

        // Mark the auction as settled
        auction.settled = true;

        // If a bid was placed:
        if (_auction.highestBidder != address(0)) {
            // Cache the amount of the highest bid
            uint256 highestBid = _auction.highestBid;

            // If the highest bid included ETH:
            if (highestBid > 0) {
                _handleOutgoingTransfer(getTimelock(), highestBid);
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
    function _createAuction() private {
        // Get the next token available for bidding
        try token.mint() returns (uint256 tokenId) {
            // Store the token id
            auction.tokenId = tokenId;

            // Cache the current block time
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

            // Reset previous auction data
            auction.highestBid = 0;
            auction.highestBidder = address(0);
            auction.settled = false;

            emit AuctionCreated(tokenId, startTime, endTime);

            // Pause the contract if token minting failed
        } catch Error(string memory) {
            _pause();
        }
    }

    ///                                                          ///
    ///                             PAUSE                        ///
    ///                                                          ///

    /// @notice Unpauses the auction house
    function unpause() external onlyOwner {
        _unpause();

        // If this is the first auction:
        if (auction.tokenId == 0) {
            // Transfer ownership of the contract to the DAO
            transferOwnership(getTimelock());

            // Start the first auction
            _createAuction();
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

    /// @notice Settles the last auction when the contract is paused
    function settleAuction() external nonReentrant whenPaused {
        _settleAuction();
    }

    ///                                                          ///
    ///                       UPDATE SETTINGS                    ///
    ///                                                          ///

    /// @notice Updates the time duration of each auction
    /// @param _duration The duration to set
    function setDuration(uint256 _duration) external onlyOwner {
        settings.duration = Cast.toUint40(_duration);

        emit DurationUpdated(_duration);
    }

    /// @notice Updates the reserve price of each auction
    /// @param _reservePrice The reserve price to set
    function setReservePrice(uint256 _reservePrice) external onlyOwner {
        settings.reservePrice = _reservePrice;

        emit ReservePriceUpdated(_reservePrice);
    }

    /// @notice Updates the minimum percentage increment required of each bid
    /// @param _percentage The percentage to set
    function setMinimumBidIncrement(uint256 _percentage) external onlyOwner {
        settings.minBidIncrement = Cast.toUint8(_percentage);

        emit MinBidIncrementPercentageUpdated(_percentage);
    }

    /// @notice Updates the time buffer of each auction
    /// @param _timeBuffer The time buffer to set
    function setTimeBuffer(uint256 _timeBuffer) external onlyOwner {
        settings.timeBuffer = Cast.toUint40(_timeBuffer);

        emit TimeBufferUpdated(_timeBuffer);
    }

    ///                                                          ///
    ///                        TRANSFER UTILS                    ///
    ///                                                          ///

    /// @notice Transfer ETH/WETH from the contract
    /// @param _to The recipient address
    /// @param _amount The amount transferring
    function _handleOutgoingTransfer(address _to, uint256 _amount) private {
        // Ensure the contract has enough balance
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
            weth.deposit{value: _amount}();

            // Transfer WETH instead
            IERC20(address(weth)).transfer(_to, _amount);
        }
    }

    ///                                                          ///
    ///                       CONTRACT UPGRADE                   ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract and the new implementation is valid
    /// @dev This function is called in `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The address of the new implementation
    function _authorizeUpgrade(address _newImpl) internal view override onlyOwner {
        // Ensure the new implementation is registered by the Builder DAO
        if (!manager.isValidUpgrade(_getImplementation(), _newImpl)) revert INVALID_UPGRADE(_newImpl);
    }
}
