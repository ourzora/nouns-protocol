// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IAuction} from "./IAuction.sol";
import {IToken} from "../token/IToken.sol";
import {IWETH} from "../token/external/IWETH.sol";

import {IUpgradeManager} from "../upgrade/IUpgradeManager.sol";
import {AuctionStorageV1} from "./storage/AuctionStorageV1.sol";

/// @title Nounish Auction
/// @author Rohan Kulkarni
/// @notice Modified version of NounsAuctionHouse.sol (commit 2cbe6c7) that Nouns licensed under the GPL-3.0 license
contract Auction is AuctionStorageV1, UUPSUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IUpgradeManager private immutable UpgradeManager;

    /// @notice The Nouns DAO Treasury
    address private immutable Nouns;

    /// @notice The Nouns Builder DAO
    address private immutable NounsBuilder;

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
        Nouns = _nouns;
        NounsBuilder = _nounsBuilder;
        WETH = _weth;
    }

    ///                                                          ///
    ///                          INITIALIZER                     ///
    ///                                                          ///

    ///
    function initialize(
        address _token,
        address _foundersDAO,
        uint256 _timeBuffer,
        uint256 _reservePrice,
        uint256 _minBidIncrementPercentage,
        uint256 _duration
    ) external initializer {
        // Initialize contract ownership
        __Ownable_init();

        // Transfer ownership to the treasury
        transferOwnership(_foundersDAO);

        // Initialize the reentrancy guard
        __ReentrancyGuard_init();

        // Pause the contract
        _pause();

        // Store the address of the token to mint
        token = IToken(_token);

        // Store the auction house config
        timeBuffer = _timeBuffer;
        reservePrice = _reservePrice;
        minBidIncrementPercentage = _minBidIncrementPercentage;
        duration = _duration;
    }

    ///                                                          ///
    ///                          CREATE BID                      ///
    ///                                                          ///

    /// @notice Emitted when a bid is placed
    ///
    ///
    ///
    ///
    ///
    event AuctionBid(uint256 tokenId, address sender, uint256 value, bool extended, uint256 endTime);

    /// @notice Creates a bid for the current token
    /// @param _tokenId The ERC-721 token id
    function createBid(uint256 _tokenId) external payable nonReentrant {
        // Get the current auction in memory
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
            // Cache the highest bid
            uint256 highestBid = _auction.highestBid;

            // Ensure the bid meets the minimum bid increase
            require(msg.value >= highestBid + ((highestBid * minBidIncrementPercentage) / 100), "MUST_MEET_MINIMUM_BID");

            // Refund the previous bidder
            _handleOutgoingTransfer(lastBidder, highestBid);
        }

        // Store the attached ETH as the highest bid
        auction.highestBid = msg.value;

        // Store the caller as the highest bidder
        auction.highestBidder = msg.sender;

        // Extend the auction if the bid was received within `timeBuffer` of the auction end time
        bool extended = _auction.endTime - block.timestamp < timeBuffer;

        if (extended) {
            auction.endTime = _auction.endTime = uint40(block.timestamp + timeBuffer);
        }

        emit AuctionBid(_tokenId, msg.sender, msg.value, extended, _auction.endTime);
    }

    ///                                                          ///
    ///                          CREATE AUCTION                  ///
    ///                                                          ///

    /// @notice Emitted when an auction is created
    event AuctionCreated(uint256 indexed nounId, uint256 startTime, uint256 endTime);

    /// @notice Creates an auction for the next token
    function _createAuction() internal {
        // Mint the next token either to this contract for bidding or to the founders if valid for vesting
        try token.mint() returns (uint256 tokenId) {
            uint256 startTime = block.timestamp;
            uint256 endTime = startTime + duration;

            auction.tokenId = tokenId;
            auction.startTime = uint40(startTime);
            auction.endTime = uint40(endTime);

            emit AuctionCreated(tokenId, startTime, endTime);

            // If the `minter` address on the `token` contract was updated without pausing this contract first:
            // Catch the error
        } catch Error(string memory) {
            // Pause this contract
            _pause();
        }
    }

    ///                                                          ///
    ///                         SETTLE AUCTION                   ///
    ///                                                          ///

    /// @notice Emitted when an auction is settled
    event AuctionSettled(uint256 indexed nounId, address winner, uint256 amount);

    /// @notice Settles the current auction
    function _settleAuction() internal {
        IAuction.Auction memory _auction = auction;

        require(_auction.startTime != 0, "NOT_STARTED");

        require(!_auction.settled, "ALREADY_SETTLED");

        require(block.timestamp >= _auction.endTime, "NOT_COMPLETED");

        // Mark the auction as settled
        auction.settled = true;

        // If there were no bids:
        if (_auction.highestBidder == address(0)) {
            // Burn the token
            token.burn(_auction.tokenId);

            // Else: transfer the the token to the winning bidder
        } else {
            token.transferFrom(address(this), _auction.highestBidder, _auction.tokenId);
        }

        if (_auction.highestBid > 0) {
            // Calculate 100 BPS of the highest bid to send to Nouns DAO and Nouns Builder DAO
            uint256 fee = (_auction.highestBid * 100) / 10_000;

            // Calculate the remaining profit
            uint256 remainingProfit = _auction.highestBid - (2 * fee);

            // Transfer to Nouns DAO
            _handleOutgoingTransfer(Nouns, fee);

            // Transfer to Nouns Builder DAO
            _handleOutgoingTransfer(NounsBuilder, fee);

            // Transfer the remaining profit to the treasury
            _handleOutgoingTransfer(owner(), remainingProfit);
        }

        emit AuctionSettled(_auction.tokenId, _auction.highestBidder, _auction.highestBid);
    }

    /// @notice Settle the auction when the contract is paused
    function settleAuction() external whenPaused nonReentrant {
        _settleAuction();
    }

    ///                                                          ///
    ///                    SETTLE & CREATE AUCTION               ///
    ///                                                          ///

    /// @notice Settles the current auction and creates the next one
    function settleCurrentAndCreateNewAuction() external nonReentrant whenNotPaused {
        _settleAuction();
        _createAuction();
    }

    ///                                                          ///
    ///                             PAUSE                        ///
    ///                                                          ///

    /// @notice Pause the auction house
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the auction house and starts the next auction
    function unpause() external onlyOwner {
        _unpause();

        // If either this is the first auction or the previous auction was settled:
        if (auction.startTime == 0 || auction.settled) {
            // Create a new auction
            _createAuction();
        }
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    ///                                                          ///
    ///                          ETH TRANSFER                    ///
    ///                                                          ///

    /// @notice Transfer ETH/WETH outbound from this contract
    function _handleOutgoingTransfer(address _dest, uint256 _amount) internal {
        // Ensure the address has
        require(address(this).balance >= _amount, "INSOLVENT");

        // Attempt the ETH transfer
        (bool success, ) = _dest.call{value: _amount, gas: 50_000}("");

        // If fails, wrap and send as WETH
        if (!success) {
            IWETH(WETH).deposit{value: _amount}();
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
