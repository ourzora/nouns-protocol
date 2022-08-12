// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

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
    IUpgradeManager private immutable upgradeManager;

    /// @notice The WETH token address
    address private immutable WETH;

    /// @notice The Nouns DAO address
    address public immutable nounsDAO;

    /// @notice The Nouns Builder DAO address
    address public immutable nounsBuilderDAO;

    /// @notice The Nouns DAO Fee
    uint256 public immutable nounsDAOFeeBPS;

    /// @notice The Nouns Builder DAO Fee
    uint256 public immutable nounsBuilderDAOFeeBPS;

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    /// @param _upgradeManager The address of the contract upgrade manager
    /// @param _weth The WETH token address
    /// @param _nounsDAO The address of the Nouns Treasury
    /// @param _nounsDAOFeeBPS The Nouns DAO Fee
    /// @param _nounsBuilderDAO The address of the Nouns Builder
    /// @param _nounsBuilderDAOFeeBPS The Nouns Builder DAO Fee
    constructor(
        address _upgradeManager,
        address _weth,
        address _nounsDAO,
        uint256 _nounsDAOFeeBPS,
        address _nounsBuilderDAO,
        uint256 _nounsBuilderDAOFeeBPS
    ) payable initializer {
        upgradeManager = IUpgradeManager(_upgradeManager);
        WETH = _weth;

        nounsDAO = _nounsDAO;
        nounsDAOFeeBPS = _nounsDAOFeeBPS;

        nounsBuilderDAO = _nounsBuilderDAO;
        nounsBuilderDAOFeeBPS = _nounsBuilderDAOFeeBPS;
    }

    ///                                                          ///
    ///                          INITIALIZER                     ///
    ///                                                          ///

    ///
    function initialize(
        address _token,
        address _foundersDAO,
        address _treasury,
        uint256 _duration,
        uint256 _reservePrice
    ) external initializer {
        // Initialize the reentrancy guard
        __ReentrancyGuard_init();

        // Initialize ownership of the contract
        __Ownable_init();

        // Pause the contract
        _pause();

        // Transfer initial ownership to the founders
        transferOwnership(_foundersDAO);

        // Store the associated token
        token = IToken(_token);

        // Store the auction house config
        house.treasury = _treasury;
        house.duration = uint40(_duration);
        house.timeBuffer = 5 minutes;
        house.minBidIncrementPercentage = 10;
        house.reservePrice = _reservePrice;
    }

    ///                                                          ///
    ///                          CREATE BID                      ///
    ///                                                          ///

    /// @notice Emitted when a bid is placed
    /// @param tokenId The ERC-721 token id
    /// @param bidder The address of the bidder
    /// @param amount The amount of ETH
    /// @param extended If the bid extended the auction
    /// @param endTime The end time of the auction
    event AuctionBid(uint256 tokenId, address bidder, uint256 amount, bool extended, uint256 endTime);

    /// @notice Creates a bid for the current token
    /// @param _tokenId The ERC-721 token id
    function createBid(uint256 _tokenId) external payable nonReentrant {
        // Get the auction in memory
        IAuction.Auction memory _auction = auction;

        // Ensure the bid is for the current token id
        require(_auction.tokenId == _tokenId, "INVALID_TOKEN_ID");

        // Ensure the auction is active
        require(block.timestamp < _auction.endTime, "AUCTION_EXPIRED");

        // Cache the highest bidder
        address lastBidder = _auction.highestBidder;

        // If this is the first bid:
        if (lastBidder == address(0)) {
            // Ensure the bid meets the reserve price
            require(msg.value >= house.reservePrice, "RESERVE_PRICE_NOT_MET");

            // Else for a subsequent bid:
        } else {
            // Cache the previous bid
            uint256 prevBid = _auction.highestBid;

            // Used to store the next bid minimum
            uint256 nextBidMin;

            // Calculate the amount of ETH required to place the next bid
            unchecked {
                nextBidMin = prevBid + ((prevBid * house.minBidIncrementPercentage) / 100);
            }

            // Ensure the bid meets the minimum
            require(msg.value >= nextBidMin, "MIN_BID_NOT_MET");

            // Refund the previous bidder
            _handleOutgoingTransfer(lastBidder, prevBid);
        }

        // Store the attached ETH as the highest bid
        auction.highestBid = msg.value;

        // Store the caller as the highest bidder
        auction.highestBidder = msg.sender;

        // Used to store if the auction will be extended
        bool extend;

        // Cannot underflow as `block.timestamp` is ensured to be less than `_auction.endTime`
        unchecked {
            // Get if the bid was placed within the time buffer of the auction end
            extend = (_auction.endTime - block.timestamp) < house.timeBuffer;
        }

        // If the auction will be extended:
        if (extend) {
            // Cannot overflow on human timescales
            unchecked {
                // Add to the current time so that the time buffer remains
                auction.endTime = _auction.endTime = uint40(block.timestamp + house.timeBuffer);
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

    /// @dev Settles the current auction
    function _settleAuction() internal {
        // Get the current auction in memory
        IAuction.Auction memory _auction = auction;

        // Ensure the auction started
        require(_auction.startTime != 0, "AUCTION_NOT_STARTED");

        // Ensure the auction ended
        require(block.timestamp >= _auction.endTime, "AUCTION_NOT_OVER");

        // Ensure the auction was not already settled
        require(!_auction.settled, "AUCTION_SETTLED");

        // Mark the auction as settled
        auction.settled = true;

        // If a bid was placed:
        if (_auction.highestBidder != address(0)) {
            // Cache the highest bid amount
            uint256 highestBid = _auction.highestBid;

            // If the highest bid included ETH:
            if (highestBid > 0) {
                // Calculate the profit after fees
                uint256 remainingProfit = _handleNounsFees(highestBid);

                // Transfer the profit to the DAO treasury
                _handleOutgoingTransfer(house.treasury, remainingProfit);
            }

            // Transfer the token to the highest bidder
            token.transferFrom(address(this), _auction.highestBidder, _auction.tokenId);

            // Delegate voting power to the winning bidder
            // This removes the need for a user to self-delegate their vote
            // token.autoDelegate(_auction.highestBidder);

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
                endTime = startTime + house.duration;
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

    // TODO optimize logic
    /// @notice Unpause the auction house
    function unpause() external onlyOwner {
        _unpause();

        // If this is the first auction:
        if (auction.tokenId == 0) {
            // Transfer ownership to the treasury
            _transferOwnership(house.treasury);

            // Create a new auction
            _createAuction();
        }
        // If the contract was paused and the previous auction was settled:
        else if (auction.settled) {
            // Create a new auction
            _createAuction();
        }
    }

    ///                                                          ///
    ///                        UPDATE DURATION                   ///
    ///                                                          ///

    /// @notice Emitted when the auction duration is updated
    /// @param duration The new auction duration
    event DurationUpdated(uint256 duration);

    /// @notice Updates the auction duration
    /// @param _duration The duration to set
    function setDuration(uint256 _duration) external onlyOwner {
        require(_duration < type(uint40).max, "INVALID_DURATION");

        house.duration = uint40(_duration);

        emit DurationUpdated(_duration);
    }

    ///                                                          ///
    ///                     UPDATE RESERVE PRICE                 ///
    ///                                                          ///

    /// @notice Emitted when the reserve price is updated
    /// @param reservePrice The new reserve price
    event ReservePriceUpdated(uint256 reservePrice);

    /// @notice Updates the reserve price
    /// @param _reservePrice The new reserve price to set
    function setReservePrice(uint256 _reservePrice) external onlyOwner {
        house.reservePrice = _reservePrice;

        emit ReservePriceUpdated(_reservePrice);
    }

    ///                                                          ///
    ///                      UPDATE BID INCREMENT                ///
    ///                                                          ///

    /// @notice Emitted when the min bid increment percentage is updated
    /// @param minBidIncrementPercentage The new min bid increment percentage
    event MinBidIncrementPercentageUpdated(uint256 minBidIncrementPercentage);

    /// @notice Updates the minimum bid increment percentage
    /// @param _minBidIncrementPercentage The new min bid increment percentage to set
    function setMinBidIncrementPercentage(uint256 _minBidIncrementPercentage) external onlyOwner {
        require(_minBidIncrementPercentage < type(uint16).max, "INVALID_BID_INCREMENT");

        house.minBidIncrementPercentage = uint16(_minBidIncrementPercentage);

        emit MinBidIncrementPercentageUpdated(_minBidIncrementPercentage);
    }

    ///                                                          ///
    ///                       UPDATE TIME BUFFER                 ///
    ///                                                          ///

    /// @notice Emitted when the time buffer is updated
    /// @param timeBuffer The new time buffer
    event TimeBufferUpdated(uint256 timeBuffer);

    /// @notice Updates the time buffer
    /// @param _timeBuffer The new time buffer to set
    function setTimeBuffer(uint256 _timeBuffer) external onlyOwner {
        require(_timeBuffer < type(uint40).max, "INVALID_TIME_BUFFER");

        house.timeBuffer = uint40(_timeBuffer);

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

    /// @dev Handles payouts to Nouns DAO and Nouns Builder DAO
    /// @param _bid The amount of ETH raised from the winning bid
    function _handleNounsFees(uint256 _bid) private returns (uint256 remainingProfit) {
        // Calculate the Nouns DAO fee from the winning bid
        uint256 nounsDAOFee = _computeFee(_bid, nounsDAOFeeBPS);

        // Calculate the Nouns Builder DAO fee from the winning bid
        uint256 nounsBuilderDAOFee = _computeFee(_bid, nounsBuilderDAOFeeBPS);

        unchecked {
            // Get the remaining profit after fees
            remainingProfit = _bid - nounsDAOFee - nounsBuilderDAOFee;
        }

        // Transfer the Nouns DAO fee to Nouns DAO
        _handleOutgoingTransfer(nounsDAO, nounsDAOFee);

        // Transfer the Nouns Builder DAO fee to Nouns Builder DAO
        _handleOutgoingTransfer(nounsBuilderDAO, nounsBuilderDAOFee);
    }

    /// @dev Computes a fee
    /// @param _amount The base amount
    /// @param _bps The fee in basis points
    function _computeFee(uint256 _amount, uint256 _bps) private pure returns (uint256 fee) {
        assembly {
            fee := div(mul(_amount, _bps), 10000)
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
        require(upgradeManager.isValidUpgrade(_getImplementation(), _newImpl), "INVALID_UPGRADE");
    }
}
