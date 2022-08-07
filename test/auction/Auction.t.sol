// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {NounsBuilderTest} from "../utils/NounsBuilderTest.sol";

contract AuctionTest is NounsBuilderTest {
    address internal bidder1;
    address internal bidder2;

    function setUp() public virtual override {
        super.setUp();

        deploy();

        bidder1 = vm.addr(0xB1);
        bidder2 = vm.addr(0xB2);

        vm.deal(bidder1, 100 ether);
        vm.deal(bidder2, 100 ether);
    }

    function test_Init() public {
        assertEq(auction.owner(), foundersDAO);

        assertEq(auction.house().treasury, address(treasury));
        assertEq(auction.house().duration, auctionParams.duration);
        assertEq(auction.house().timeBuffer, 5 minutes);
        assertEq(auction.house().minBidIncrementPercentage, 10);
        assertEq(auction.house().reservePrice, auctionParams.reservePrice);
    }

    // function test_AuctionStart() public {
    //     vm.prank(foundersDAO);
    //     auction.unpause();

    //     assertEq(auction.owner(), address(treasury));

    //     assertEq(auction.token().ownerOf(0), foundersDAO);
    //     assertEq(auction.token().ownerOf(1), address(auction));

    //     assertEq(auction.auction().tokenId, 1);
    //     assertEq(auction.auction().highestBid, 0);
    //     assertEq(auction.auction().highestBidder, address(0));
    //     assertEq(auction.auction().startTime, 1);
    //     assertEq(auction.auction().endTime, 1 + auctionParams.duration);
    //     assertEq(auction.auction().settled, false);
    // }

    // function testRevert_OnlyOwnerCanUnpause() public {
    //     vm.expectRevert("Ownable: caller is not the owner");
    //     auction.unpause();
    // }

    // function test_CreateBid() public {
    //     vm.prank(foundersDAO);
    //     auction.unpause();

    //     vm.prank(bidder1);
    //     auction.createBid{value: 0.420 ether}(1);

    //     assertEq(auction.auction().highestBid, 0.420 ether);
    //     assertEq(auction.auction().highestBidder, bidder1);

    //     assertEq(bidder1.balance, 99.58 ether);
    //     assertEq(address(auction).balance, 0.420 ether);
    // }

    // function test_CreateSubsequentBid() public {
    //     vm.prank(foundersDAO);
    //     auction.unpause();

    //     vm.prank(bidder1);
    //     auction.createBid{value: 0.420 ether}(1);

    //     vm.warp(5 minutes);

    //     vm.prank(bidder2);
    //     auction.createBid{value: 1 ether}(1);

    //     assertEq(auction.auction().highestBid, 1 ether);
    //     assertEq(auction.auction().highestBidder, bidder2);

    //     assertEq(bidder2.balance, 99 ether);
    //     assertEq(address(auction).balance, 1 ether);
    // }

    // function test_ExtendAuction() public {
    //     vm.prank(foundersDAO);
    //     auction.unpause();

    //     vm.prank(bidder1);
    //     auction.createBid{value: 0.420 ether}(1);

    //     vm.warp(9 minutes);

    //     vm.prank(bidder2);
    //     auction.createBid{value: 1 ether}(1);

    //     assertEq(auction.auction().endTime, 14 minutes);
    // }

    // function testRevert_InvalidTokenId() public {
    //     vm.prank(foundersDAO);
    //     auction.unpause();

    //     vm.prank(bidder1);
    //     vm.expectRevert("INVALID_TOKEN_ID");
    //     auction.createBid{value: 0.420 ether}(2);
    // }

    // function testRevert_AuctionExpired() public {
    //     vm.prank(foundersDAO);
    //     auction.unpause();

    //     vm.warp(10 minutes + 1 seconds);

    //     vm.prank(bidder1);
    //     vm.expectRevert("AUCTION_EXPIRED");
    //     auction.createBid{value: 0.420 ether}(1);
    // }

    // function testRevert_MustMeetReservePrice() public {
    //     vm.prank(foundersDAO);
    //     auction.unpause();

    //     vm.prank(bidder1);
    //     vm.expectRevert("RESERVE_PRICE_NOT_MET");
    //     auction.createBid(1);
    // }

    // function testRevert_MustMeetMinBidIncrement() public {
    //     vm.prank(foundersDAO);
    //     auction.unpause();

    //     vm.prank(bidder1);
    //     auction.createBid{value: 0.420 ether}(1);

    //     vm.warp(5 minutes);

    //     vm.prank(bidder2);
    //     vm.expectRevert("MIN_BID_NOT_MET");
    //     auction.createBid{value: 0.461 ether}(1);
    // }

    // function test_SettleAuction() public {
    //     vm.prank(foundersDAO);
    //     auction.unpause();

    //     vm.prank(bidder1);
    //     auction.createBid{value: 0.420 ether}(1);

    //     vm.prank(bidder2);
    //     auction.createBid{value: 1 ether}(1);

    //     vm.warp(10 minutes + 1 seconds);

    //     auction.settleCurrentAndCreateNewAuction();

    //     assertEq(token.ownerOf(1), bidder2);
    //     assertEq(token.getVotes(bidder2), 1);

    //     assertEq(auction.house().treasury.balance, 0.98 ether);

    //     assertEq(nounsDAO.balance, 0.01 ether);
    //     assertEq(nounsBuilderDAO.balance, 0.01 ether);
    // }

    // function testRevert_AuctionStillActive() public {
    //     vm.prank(foundersDAO);
    //     auction.unpause();

    //     vm.prank(bidder1);
    //     auction.createBid{value: 0.420 ether}(1);

    //     vm.warp(5 minutes);

    //     vm.prank(bidder2);
    //     auction.createBid{value: 1 ether}(1);

    //     vm.expectRevert("AUCTION_NOT_OVER");
    //     auction.settleCurrentAndCreateNewAuction();
    // }

    // function testFail_BurnToken() public {
    //     vm.prank(foundersDAO);
    //     auction.unpause();

    //     vm.warp(10 minutes + 1 seconds);
    //     auction.settleCurrentAndCreateNewAuction();

    //     auction.token().ownerOf(1);
    // }

    // function test_SettleAuctionWhenPaused() public {
    //     vm.prank(foundersDAO);
    //     auction.unpause();

    //     vm.prank(bidder1);
    //     auction.createBid{value: 0.420 ether}(1);

    //     vm.prank(bidder2);
    //     auction.createBid{value: 1 ether}(1);

    //     vm.warp(10 minutes + 1 seconds);

    //     vm.prank(address(treasury));
    //     auction.pause();

    //     auction.settleAuction();

    //     assertEq(auction.auction().settled, true);
    // }
}
