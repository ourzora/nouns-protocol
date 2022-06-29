// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AuctionStorageV1} from "./storage/AuctionStorageV1.sol";
import {IAuction} from "./IAuction.sol";
import {IToken} from "../token/IToken.sol";
import {IWETH} from "../token/external/IWETH.sol";
import {IUpgradeManager} from "../upgrade/IUpgradeManager.sol";

/// @title Nounish Auction
/// @author Rohan Kulkarni
/// @notice Modified version of NounsAuctionHouse.sol (commit 2cbe6c7) that Nouns licensed under the GPL-3.0 license
contract Auction is UUPSUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable, PausableUpgradeable, AuctionStorageV1 {
    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IUpgradeManager private immutable UpgradeManager;

    /// @notice The Nouns DAO address
    address private immutable NounsDAO;

    /// @notice The Nouns Builder DAO address
    address private immutable NounsBuilderDAO;

    /// @notice The WETH token address
    address private immutable WETH;

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    /// @param _upgradeManager The address of the contract upgrade manager
    /// @param _nouns The address of the Nouns Treasury
    /// @param _nounsBuilder The address of the Nouns Builder
    /// @param _weth The WETH token address
    constructor(
        address _upgradeManager,
        address _nouns,
        address _nounsBuilder,
        address _weth
    ) payable initializer {
        UpgradeManager = IUpgradeManager(_upgradeManager);
        NounsDAO = _nouns;
        NounsBuilderDAO = _nounsBuilder;
        WETH = _weth;
    }

    ///                                                          ///
    ///                          INITIALIZER                     ///
    ///                                                          ///

    ///
    function initialize(
        address _token,
        address _foundersDAO,
        address _treasury,
        uint256 _timeBuffer,
        uint256 _reservePrice,
        uint256 _minBidIncrementPercentage,
        uint256 _duration
    ) external initializer {
        // Initialize the reentrancy guard
        __ReentrancyGuard_init();

        // Initialize ownership of the contract
        __Ownable_init();

        // Pause the contract
        _pause();

        // Transfer ownership to the founders
        transferOwnership(_foundersDAO);

        // Store the associated token
        token = IToken(_token);

        //
        treasury = _treasury;
        timeBuffer = _timeBuffer;
        reservePrice = _reservePrice;
        minBidIncrementPercentage = _minBidIncrementPercentage;
        duration = _duration;
    }

    ///                                                          ///
    ///                          CREATE BID                      ///
    ///                                                          ///

    /// @notice Emitted when a bid is placed
    event AuctionBid(uint256 tokenId, address sender, uint256 value, bool extended, uint256 endTime);

    /// @notice Creates a bid for the current token
    /// @param _tokenId The ERC-721 token id
    function createBid(uint256 _tokenId) external payable nonReentrant {
        // Get the auction in memory
        IAuction.Auction memory _auction = auction;

        // Ensure the bid is for the current token id
        require(_auction.tokenId == _tokenId, "INVALID_TOKEN_ID");

        // Ensure the auction is still active
        require(block.timestamp < _auction.endTime, "AUCTION_EXPIRED");

        // Cache the highest bidder
        address lastBidder = _auction.highestBidder;

        // If this is the first bid:
        if (lastBidder == address(0)) {
            // Ensure the bid meets the reserve price
            require(msg.value >= reservePrice, "MUST_MEET_RESERVE_PRICE");

            // Else this is a subsequent bid:
        } else {
            // Cache the previous highest bid
            uint256 prevBid = _auction.highestBid;

            // Used to store the next minimum bid
            uint256 minRaiseAmount;

            // Calculate the minimum amount of ETH required to place a subsequent bid
            unchecked {
                minRaiseAmount = prevBid + ((prevBid * minBidIncrementPercentage) / 100);
            }

            // Ensure the bid meets the minimum bid increase
            require(msg.value >= minRaiseAmount, "MUST_MEET_MINIMUM_BID");

            // Refund the previous bidder
            _handleOutgoingTransfer(lastBidder, prevBid);
        }

        // Store the attached ETH as the highest bid
        auction.highestBid = msg.value;

        // Store the caller as the highest bidder
        auction.highestBidder = msg.sender;

        // Used to store if the auction will be extended
        bool extend;

        // Check if the bid was placed within the `timeBuffer` of the auction end time
        // Cannot underflow as `block.timestamp` is ensured to be less than `_auction.endTime` on line 109
        unchecked {
            extend = (_auction.endTime - block.timestamp) < timeBuffer;
        }

        // If the auction will be extended:
        if (extend) {
            // Add the `timeBuffer` to the current time and store as the new end time
            //
            unchecked {
                auction.endTime = _auction.endTime = uint40(block.timestamp + timeBuffer);
            }
        }

        emit AuctionBid(_tokenId, msg.sender, msg.value, extend, _auction.endTime);
    }

    ///                                                          ///
    ///                         SETTLE AUCTION                   ///
    ///                                                          ///

    /// @notice Emitted when an auction is settled
    /// @param tokenId The ERC-721 token id of the settled auction
    /// @param winner The address of the winning bidder
    /// @param amount The amount of ETH raised from the winning bid
    event AuctionSettled(uint256 tokenId, address winner, uint256 amount);

    /// @notice Settles the current auction and creates the next one
    function settleCurrentAndCreateNewAuction() external nonReentrant whenNotPaused {
        _settleAuction();
        _createAuction();
    }

    /// @notice Settles the current auction when the contract is paused
    function settleAuction() external nonReentrant whenPaused {
        _settleAuction();
    }

    /// @notice Settles the current auction
    function _settleAuction() internal {
        // Get the current auction in memory
        IAuction.Auction memory _auction = auction;

        // Ensure the auction started
        require(_auction.startTime != 0, "AUCTION_NOT_STARTED");

        // Ensure the auction ended
        require(block.timestamp >= _auction.endTime, "AUCTION_STILL_ACTIVE");

        // Ensure the auction was not settled
        require(!_auction.settled, "AUCTION_ALREADY_SETTLED");

        // Mark the auction as settled
        auction.settled = true;

        // If a bid was placed:
        if (_auction.highestBidder != address(0)) {
            // Transfer the token to the highest bidder
            token.transferFrom(address(this), _auction.highestBidder, _auction.tokenId);

            // If ETH was included in the bid:
            if (_auction.highestBid > 0) {
                //
                uint256 fee;

                //
                unchecked {
                    fee = (_auction.highestBid * 100) / 10_000;
                }

                // Calculate the remaining profit to the treasury
                uint256 remainingProfit;

                //
                unchecked {
                    remainingProfit = _auction.highestBid - (2 * fee);
                }

                // Transfer 100 bps to Nouns DAO
                _handleOutgoingTransfer(NounsDAO, fee);

                // Transfer 100 bps to Nouns Builder DAO
                _handleOutgoingTransfer(NounsBuilderDAO, fee);

                // Transfer the remaining profit to the treasury
                _handleOutgoingTransfer(treasury, remainingProfit);
            }

            // Else no bid was placed:
        } else {
            // Burn the token
            token.burn(_auction.tokenId);
        }

        emit AuctionSettled(_auction.tokenId, _auction.highestBidder, _auction.highestBid);
    }

    ///                                                          ///
    ///                         CREATE AUCTION                   ///
    ///                                                          ///

    /// @notice Emitted when an auction is created
    /// @param tokenId The ERC-721 token id of the created auction
    /// @param startTime The start time of the created auction
    /// @param endTime The end time of the created auction
    event AuctionCreated(uint256 tokenId, uint256 startTime, uint256 endTime);

    /// @notice Creates an auction for the next token
    function _createAuction() internal {
        // Mint the next token either to this contract for bidding or to the founders if valid for vesting
        try token.mint() returns (uint256 tokenId) {
            //
            auction.tokenId = tokenId;

            //
            uint256 startTime = block.timestamp;

            //
            uint256 endTime;

            //
            unchecked {
                endTime = startTime + duration;
            }

            //
            auction.startTime = uint40(startTime); // block.timestamp
            auction.endTime = uint40(endTime); // block.timestamp + duration

            auction.highestBid = 0;
            auction.highestBidder = address(0);
            auction.settled = false;

            emit AuctionCreated(tokenId, startTime, endTime);

            // If the `auction` address on the `token` contract was updated without pausing this contract first:
        } catch Error(string memory) {
            _pause();
        }
    }

    ///                                                          ///
    ///                             PAUSE                        ///
    ///                                                          ///

    /// @notice Pause the auction house
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the auction house
    function unpause() external onlyOwner {
        _unpause();

        // If this is the first auction OR the previous auction was settled:
        if (auction.startTime == 0 || auction.settled) {
            // Create a new auction
            _createAuction();
        }
    }

    ///                                                          ///
    ///                        UPDATE DURATION                   ///
    ///                                                          ///

    ///
    ///
    event DurationUpdated(uint256 duration);

    ///
    ///
    function setDuration(uint256 _duration) external onlyOwner {
        duration = _duration;

        emit DurationUpdated(_duration);
    }

    ///                                                          ///
    ///                     UPDATE RESERVE PRICE                 ///
    ///                                                          ///

    ///
    ///
    event ReservePriceUpdated(uint256 reservePrice);

    ///
    ///
    function setReservePrice(uint256 _reservePrice) external onlyOwner {
        reservePrice = _reservePrice;

        emit ReservePriceUpdated(_reservePrice);
    }

    ///                                                          ///
    ///                      UPDATE BID INCREMENT                ///
    ///                                                          ///

    ///
    ///
    event MinBidIncrementPercentageUpdated(uint256 minBidIncrementPercentage);

    ///
    ///
    function setMinBidIncrementPercentage(uint256 _minBidIncrementPercentage) external onlyOwner {
        minBidIncrementPercentage = _minBidIncrementPercentage;

        emit MinBidIncrementPercentageUpdated(_minBidIncrementPercentage);
    }

    ///                                                          ///
    ///                       UPDATE TIME BUFFER                 ///
    ///                                                          ///

    ///
    ///
    event TimeBufferUpdated(uint256 timeBuffer);

    ///
    ///
    function setTimeBuffer(uint256 _timeBuffer) external onlyOwner {
        timeBuffer = _timeBuffer;

        emit TimeBufferUpdated(_timeBuffer);
    }

    ///                                                          ///
    ///                          ETH TRANSFER                    ///
    ///                                                          ///

    /// @notice Transfer ETH/WETH outbound from this contract
    /// @param _dest The address of the destination
    /// @param _amount The amount of ETH to transfer
    function _handleOutgoingTransfer(address _dest, uint256 _amount) internal {
        // Ensure the contract holds enough ETH
        require(address(this).balance >= _amount, "INSOLVENT");

        // Transfer the given amount of ETH to the given destination
        (bool success, ) = _dest.call{value: _amount, gas: 50_000}("");

        // If the transfer fails:
        if (!success) {
            // Wrap the ETH as WETH
            IWETH(WETH).deposit{value: _amount}();

            // Transfer as WETH instead
            IERC20(WETH).transfer(_dest, _amount);
        }
    }

    ///                                                          ///
    ///                         PROXY UPGRADE                    ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract to a valid implementation
    /// @dev This function is called in UUPS `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The address of the new implementation
    function _authorizeUpgrade(address _newImpl) internal override onlyOwner {
        // Ensure the implementation is valid
        require(UpgradeManager.isValidUpgrade(_getImplementation(), _newImpl), "INVALID_UPGRADE");
    }
}
