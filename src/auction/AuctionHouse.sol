// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IAuctionHouse} from "./IAuctionHouse.sol";
import {IToken} from "../token/IToken.sol";
import {IWETH} from "../token/external/IWETH.sol";

import {IUpgradeManager} from "../upgrades/IUpgradeManager.sol";
import {AuctionHouseStorageV1} from "./storage/AuctionHouseStorageV1.sol";

/// @title Nounish Auction House
/// @author Rohan Kulkarni
/// @notice Modified version of NounsAuctionHouse.sol (commit 2cbe6c7) that NounsDAO licensed under the GPL-3.0 license
contract AuctionHouse is AuctionHouseStorageV1, UUPSUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IUpgradeManager private immutable UpgradeManager;

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    /// @param _upgradeManager The address of the contract upgrade manager
    constructor(address _upgradeManager) payable initializer {
        UpgradeManager = IUpgradeManager(_upgradeManager);
    }

    ///                                                          ///
    ///                          INITIALIZER                     ///
    ///                                                          ///

    function initialize(
        address _token,
        address _weth,
        uint256 _timeBuffer,
        uint256 _reservePrice,
        uint256 _minBidIncrementPercentage,
        uint256 _duration,
        address _treasury
    ) external initializer {
        // Initialize the proxy
        __UUPSUpgradeable_init();

        // Initialize contract ownership
        __Ownable_init();

        // Transfer ownership to the treasury
        transferOwnership(_treasury);

        // Initialize the reentrancy guard
        __ReentrancyGuard_init();

        // Initialize the ability to pause the contract
        __Pausable_init();

        // Pause the contract
        _pause();

        // Store the address of the token to mint
        token = IToken(_token);

        // Store the address of WETH
        weth = _weth;

        // Initialize the auction house metadata
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
        // Cache the current auction in memory
        Auction memory _auction = auction;

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

        emit AuctionBid(_auction.tokenId, msg.sender, msg.value, extended, _auction.endTime);
    }

    ///                                                          ///
    ///                    SETTLE AND CREATE AUCTION             ///
    ///                                                          ///

    /// @notice Settles the current auction and creates the next one
    function settleCurrentAndCreateNewAuction() external nonReentrant whenNotPaused {
        _settleAuction();
        _createAuction();
    }

    /// @notice Emitted when an auction is settled
    event AuctionSettled(uint256 indexed nounId, address winner, uint256 amount);

    /// @notice Settles the current auction
    function _settleAuction() internal {
        Auction memory _auction = auction;

        require(_auction.startTime != 0, "NOT_STARTED");
        require(!_auction.settled, "ALREADY_SETTLED");
        require(block.timestamp >= _auction.endTime, "NOT_COMPLETED");

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
            _handleOutgoingTransfer(owner(), _auction.highestBid);
        }

        emit AuctionSettled(_auction.tokenId, _auction.highestBidder, _auction.highestBid);
    }

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
    ///                       UPDATE TIME BUFFER                 ///
    ///                                                          ///

    /// @notice Emitted when the time buffer is updated
    event AuctionTimeBufferUpdated(uint256 timeBuffer);

    /// @notice Updates the auction time buffer
    /// @param _timeBuffer The time buffer to set
    function setTimeBuffer(uint256 _timeBuffer) external onlyOwner {
        // Update the time buffer
        timeBuffer = _timeBuffer;

        emit AuctionTimeBufferUpdated(_timeBuffer);
    }

    ///                                                          ///
    ///                      UPDATE RESERVE PRICE                ///
    ///                                                          ///

    /// @notice Emitted when the reserve price is updated
    event AuctionReservePriceUpdated(uint256 reservePrice);

    /// @notice Updates the auction reserve price
    /// @param _reservePrice The reserve price to set
    function setReservePrice(uint256 _reservePrice) external onlyOwner {
        // Update the reserve price
        reservePrice = _reservePrice;

        emit AuctionReservePriceUpdated(_reservePrice);
    }

    ///                                                          ///
    ///                 UPDATE MINIMUM BID INCREMENT             ///
    ///                                                          ///

    /// @notice Emitted when the min bid increment percentage is updated
    event AuctionMinBidIncrementPercentageUpdated(uint256 minBidIncrementPercentage);

    /// @notice Updates the auction minimum bid increment percentage
    /// @param _minBidIncrementPercentage The min bid increment percentage to set
    function setMinBidIncrementPercentage(uint256 _minBidIncrementPercentage) external onlyOwner {
        minBidIncrementPercentage = _minBidIncrementPercentage;

        emit AuctionMinBidIncrementPercentageUpdated(_minBidIncrementPercentage);
    }

    ///                                                          ///
    ///                           DAO PAUSE                      ///
    ///                                                          ///

    /// @notice Pause the auction house
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the auction house
    function unpause() external onlyOwner {
        _unpause();

        if (auction.startTime == 0 || auction.settled) {
            _createAuction();
        }
    }

    /// @notice Settle the auction when the contract is paused
    function settleAuction() external whenPaused nonReentrant {
        _settleAuction();
    }

    ///                                                          ///
    ///                          ETH TRANSFER                    ///
    ///                                                          ///

    /// @notice The WETH token address
    address public weth;

    /// @notice Transfer ETH/WETH outbound from this contract
    function _handleOutgoingTransfer(address _dest, uint256 _amount) internal {
        // Ensure the address has
        require(address(this).balance >= _amount, "INSOLVENT");

        // Attempt the ETH transfer
        (bool success, ) = _dest.call{value: _amount, gas: 50_000}("");

        // If fails, wrap and send as WETH
        if (!success) {
            IWETH(weth).deposit{value: _amount}();
            IERC20(weth).transfer(_dest, _amount);
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
