// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {IToken} from "../token/IToken.sol";

interface IAuction {
    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    struct Auction {
        uint256 tokenId;
        uint256 highestBid;
        address highestBidder;
        uint40 startTime;
        uint40 endTime;
        bool settled;
    }

    struct House {
        address treasury;
        uint40 duration;
        uint40 timeBuffer;
        uint16 minBidIncrementPercentage;
        uint256 reservePrice;
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function initialize(
        address token,
        address foundersDAO,
        address treasury,
        uint256 duration,
        uint256 reservePrice
    ) external;

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function token() external view returns (IToken);

    function auction() external view returns (Auction calldata);

    function house() external view returns (House calldata);

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function createBid(uint256 tokenId) external payable;

    function settleCurrentAndCreateNewAuction() external;

    function settleAuction() external;

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function paused() external view returns (bool);

    function unpause() external;

    function pause() external;

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

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

    function upgradeTo(address implementation) external;

    function upgradeToAndCall(address implementation, bytes memory data) external payable;
}
