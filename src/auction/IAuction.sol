// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { IUUPS } from "../lib/interfaces/IUUPS.sol";
import { IOwnable } from "../lib/interfaces/IOwnable.sol";
import { IPausable } from "../lib/interfaces/IPausable.sol";

/// @title IAuction
/// @author Rohan Kulkarni
/// @notice The external Auction events, errors, and functions
interface IAuction is IUUPS, IOwnable, IPausable {
    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    /// @notice Emitted when a bid is placed
    /// @param tokenId The ERC-721 token id
    /// @param bidder The address of the bidder
    /// @param amount The amount of ETH
    /// @param extended If the bid extended the auction
    /// @param endTime The end time of the auction
    event AuctionBid(uint256 tokenId, address bidder, uint256 amount, bool extended, uint256 endTime);

    /// @notice Emitted when an auction is settled
    /// @param tokenId The ERC-721 token id of the settled auction
    /// @param winner The address of the winning bidder
    /// @param amount The amount of ETH raised from the winning bid
    event AuctionSettled(uint256 tokenId, address winner, uint256 amount);

    /// @notice Emitted when an auction is created
    /// @param tokenId The ERC-721 token id of the created auction
    /// @param startTime The start time of the created auction
    /// @param endTime The end time of the created auction
    event AuctionCreated(uint256 tokenId, uint256 startTime, uint256 endTime);

    /// @notice Emitted when the auction duration is updated
    /// @param duration The new auction duration
    event DurationUpdated(uint256 duration);

    /// @notice Emitted when the reserve price is updated
    /// @param reservePrice The new reserve price
    event ReservePriceUpdated(uint256 reservePrice);

    /// @notice Emitted when the min bid increment percentage is updated
    /// @param minBidIncrementPercentage The new min bid increment percentage
    event MinBidIncrementPercentageUpdated(uint256 minBidIncrementPercentage);

    /// @notice Emitted when the time buffer is updated
    /// @param timeBuffer The new time buffer
    event TimeBufferUpdated(uint256 timeBuffer);

    ///                                                          ///
    ///                           ERRORS                         ///
    ///                                                          ///

    /// @dev Reverts if a bid is placed for the wrong token
    error INVALID_TOKEN_ID();

    /// @dev Reverts if a bid is placed for an auction thats over
    error AUCTION_OVER();

    /// @dev Reverts if a bid is placed for an auction that hasn't started
    error AUCTION_NOT_STARTED();

    /// @dev Reverts if attempting to settle an active auction
    error AUCTION_ACTIVE();

    /// @dev Reverts if attempting to settle an auction that was already settled
    error AUCTION_SETTLED();

    /// @dev Reverts if a bid does not meet the reserve price
    error RESERVE_PRICE_NOT_MET();

    /// @dev Reverts if a bid does not meet the minimum bid
    error MINIMUM_BID_NOT_MET();

    /// @dev Reverts if the contract does not have enough ETH
    error INSOLVENT();

    /// @dev Reverts if the caller was not the contract manager
    error ONLY_MANAGER();

    /// @dev Thrown if the WETH contract throws a failure on transfer
    error FAILING_WETH_TRANSFER();

    /// @dev Thrown if the auction creation failed
    error AUCTION_CREATE_FAILED_TO_LAUNCH();

    ///                                                          ///
    ///                          FUNCTIONS                       ///
    ///                                                          ///

    /// @notice Initializes a DAO's auction house
    /// @param token The ERC-721 token address
    /// @param founder The founder responsible for starting the first auction
    /// @param treasury The treasury address where ETH will be sent
    /// @param duration The duration of each auction
    /// @param reservePrice The reserve price of each auction
    function initialize(
        address token,
        address founder,
        address treasury,
        uint256 duration,
        uint256 reservePrice
    ) external;

    /// @notice Creates a bid for the current token
    /// @param tokenId The ERC-721 token id
    function createBid(uint256 tokenId) external payable;

    /// @notice Settles the current auction and creates the next one
    function settleCurrentAndCreateNewAuction() external;

    /// @notice Settles the latest auction when the contract is paused
    function settleAuction() external;

    /// @notice Pauses the auction house
    function pause() external;

    /// @notice Unpauses the auction house
    function unpause() external;

    /// @notice The time duration of each auction
    function duration() external view returns (uint256);

    /// @notice The reserve price of each auction
    function reservePrice() external view returns (uint256);

    /// @notice The minimum amount of time to place a bid during an active auction
    function timeBuffer() external view returns (uint256);

    /// @notice The minimum percentage an incoming bid must raise the highest bid
    function minBidIncrement() external view returns (uint256);

    /// @notice Updates the time duration of each auction
    /// @param duration The new time duration
    function setDuration(uint256 duration) external;

    /// @notice Updates the reserve price of each auction
    /// @param reservePrice The new reserve price
    function setReservePrice(uint256 reservePrice) external;

    /// @notice Updates the time buffer of each auction
    /// @param timeBuffer The new time buffer
    function setTimeBuffer(uint256 timeBuffer) external;

    /// @notice Updates the minimum bid increment of each subsequent bid
    /// @param percentage The new percentage
    function setMinimumBidIncrement(uint256 percentage) external;

    /// @notice Get the address of the treasury
    function treasury() external returns (address);
}
