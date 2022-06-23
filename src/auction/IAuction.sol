// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {IToken} from "../token/IToken.sol";

interface IAuction {
    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function initialize(
        address _token,
        address _treasury,
        uint256 _timeBuffer,
        uint256 _reservePrice,
        uint256 _minBidIncrementPercentage,
        uint256 _duration
    ) external;

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    /// @notice The metadata type of an auction
    /// @param tokenId The ERC-721 token id
    /// @param highestBid The highest bid amount
    /// @param highestBidder The address of the highest bidder
    /// @param startTime The time that the auction started
    /// @param endTime The time that the auction is scheduled to end
    /// @param settled If the auction has been settled
    struct Auction {
        uint256 tokenId;
        uint256 highestBid;
        address highestBidder;
        uint40 startTime;
        uint40 endTime;
        bool settled;
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function token() external view returns (IToken);

    function auction() external view returns (Auction calldata);

    function duration() external view returns (uint256);

    function reservePrice() external view returns (uint256);

    function timeBuffer() external view returns (uint256);

    function minBidIncrementPercentage() external view returns (uint256);

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function settleAuction() external;

    function settleCurrentAndCreateNewAuction() external;

    function createBid(uint256 nounId) external payable;

    function paused() external view returns (bool);

    function pause() external;

    function unpause() external;

    function setTimeBuffer(uint256 timeBuffer) external;

    function setReservePrice(uint256 reservePrice) external;

    function setMinBidIncrementPercentage(uint256 minBidIncrementPercentage) external;

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function owner() external view returns (address);

    function transferOwnership(address newOwner) external;

    function renounceOwnership() external;

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function upgradeTo(address newImplementation) external;

    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
}
