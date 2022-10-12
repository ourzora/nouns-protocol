// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { NounsBuilderTest } from "./utils/NounsBuilderTest.sol";
import { MockERC721 } from "./utils/mocks/MockERC721.sol";
import { MockImpl } from "./utils/mocks/MockImpl.sol";

contract AuctionTest is NounsBuilderTest {
    MockImpl internal mockImpl;

    address internal bidder1;
    address internal bidder2;

    function setUp() public virtual override {
        super.setUp();

        bidder1 = vm.addr(0xB1);
        bidder2 = vm.addr(0xB2);

        vm.deal(bidder1, 100 ether);
        vm.deal(bidder2, 100 ether);

        mockImpl = new MockImpl();
    }

    function test_AuctionHouseInitialized() public {
        deployMock();

        assertEq(auction.owner(), founder);

        assertEq(auction.treasury(), address(treasury));
        assertEq(auction.duration(), auctionParams.duration);
        assertEq(auction.reservePrice(), auctionParams.reservePrice);
        assertEq(auction.timeBuffer(), 5 minutes);
        assertEq(auction.minBidIncrement(), 10);
    }

    function testRevert_AlreadyInitialized() public {
        deployMock();

        vm.expectRevert(abi.encodeWithSignature("ALREADY_INITIALIZED()"));
        auction.initialize(address(token), address(this), address(treasury), 1 minutes, 0 ether);
    }

    function test_Unpause() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        assertEq(auction.owner(), address(treasury));

        assertEq(token.ownerOf(0), founder);
        assertEq(token.ownerOf(1), founder2);
        assertEq(token.ownerOf(2), address(auction));

        (uint256 tokenId, uint256 highestBid, address highestBidder, uint256 startTime, uint256 endTime, bool settled) = auction.auction();

        assertEq(tokenId, 2);
        assertEq(highestBid, 0);
        assertEq(highestBidder, address(0));
        assertEq(startTime, 1);
        assertEq(endTime, 1 + auctionParams.duration);
        assertEq(settled, false);
    }

    function testRevert_OnlyFounderCanUnpause() public {
        deployMock();

        vm.expectRevert(abi.encodeWithSignature("ONLY_OWNER()"));
        auction.unpause();
    }

    function test_CreateBid(uint256 _amount) public {
        deployMock();

        vm.assume(_amount >= auction.reservePrice() && _amount <= bidder1.balance);

        vm.prank(founder);
        auction.unpause();

        uint256 beforeBidderBalance = bidder1.balance;
        uint256 beforeAuctionBalance = address(auction).balance;

        vm.prank(bidder1);
        auction.createBid{ value: _amount }(2);

        (, uint256 highestBid, address highestBidder, , , ) = auction.auction();

        assertEq(highestBid, _amount);
        assertEq(highestBidder, bidder1);

        uint256 afterBidderBalance = bidder1.balance;
        uint256 afterAuctionBalance = address(auction).balance;

        assertEq(beforeBidderBalance - afterBidderBalance, _amount);
        assertEq(afterAuctionBalance - beforeAuctionBalance, _amount);
    }

    function testRevert_InvalidBidTokenId() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        vm.prank(bidder1);
        vm.expectRevert(abi.encodeWithSignature("INVALID_TOKEN_ID()"));
        auction.createBid{ value: 0.420 ether }(3);
    }

    function testRevert_MustMeetReservePrice() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        vm.prank(bidder1);
        vm.expectRevert(abi.encodeWithSignature("RESERVE_PRICE_NOT_MET()"));
        auction.createBid{ value: 0.0001 ether }(2);
    }

    function test_CreateSubsequentBid() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        uint256 bidder1BeforeBalance = bidder1.balance;
        uint256 bidder2BeforeBalance = bidder2.balance;

        vm.prank(bidder1);
        auction.createBid{ value: 0.1 ether }(2);

        vm.warp(5 minutes);

        vm.prank(bidder2);
        auction.createBid{ value: 0.5 ether }(2);

        uint256 bidder1AfterBalance = bidder1.balance;
        uint256 bidder2AfterBalance = bidder2.balance;

        assertEq(bidder1BeforeBalance, bidder1AfterBalance);
        assertEq(bidder2BeforeBalance - bidder2AfterBalance, 0.5 ether);
        assertEq(address(auction).balance, 0.5 ether);

        (, uint256 highestBid, address highestBidder, , , ) = auction.auction();

        assertEq(highestBid, 0.5 ether);
        assertEq(highestBidder, bidder2);
    }

    function testRevert_MustMeetMinBidIncrement() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        vm.prank(bidder1);
        auction.createBid{ value: 0.420 ether }(2);

        vm.warp(5 minutes);

        vm.prank(bidder2);
        vm.expectRevert(abi.encodeWithSignature("MINIMUM_BID_NOT_MET()"));
        auction.createBid{ value: 0.461 ether }(2);
    }

    function test_ExtendAuction() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        vm.prank(bidder1);
        auction.createBid{ value: 0.420 ether }(2);

        vm.warp(9 minutes);

        vm.prank(bidder2);
        auction.createBid{ value: 1 ether }(2);

        (, , , , uint256 endTime, ) = auction.auction();

        assertEq(endTime, 14 minutes);
    }

    function testRevert_AuctionExpired() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        vm.warp(10 minutes + 1 seconds);

        vm.prank(bidder1);
        vm.expectRevert(abi.encodeWithSignature("AUCTION_OVER()"));
        auction.createBid{ value: 0.420 ether }(2);
    }

    function test_SettleAuction() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        vm.prank(bidder1);
        auction.createBid{ value: 0.420 ether }(2);

        vm.prank(bidder2);
        auction.createBid{ value: 1 ether }(2);

        vm.warp(10 minutes + 1 seconds);

        auction.settleCurrentAndCreateNewAuction();

        assertEq(token.ownerOf(2), bidder2);
        assertEq(token.getVotes(bidder2), 1);

        assertEq(address(treasury).balance, 1 ether);
    }

    function test_PausesWhenMintFails() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        vm.prank(bidder1);
        auction.createBid{ value: 0.420 ether }(2);

        vm.warp(10 minutes + 1 seconds);

        vm.prank(zoraDAO);
        manager.registerUpgrade(tokenImpl, address(mock721));

        // Upgrade token to invalid contract
        vm.prank(address(treasury));
        token.upgradeTo(address(mock721));

        // mint token to transfer
        MockERC721(address(token)).mint(address(auction), 2);

        // this fails the new mint and should pause the auction
        auction.settleCurrentAndCreateNewAuction();
        assertTrue(auction.paused());
    }

    function testRevert_CannotSettleWhenAuctionStillActive() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        vm.prank(bidder1);
        auction.createBid{ value: 0.420 ether }(2);

        vm.warp(5 minutes);

        vm.prank(bidder2);
        auction.createBid{ value: 1 ether }(2);

        vm.expectRevert(abi.encodeWithSignature("AUCTION_ACTIVE()"));
        auction.settleCurrentAndCreateNewAuction();
    }

    function testRevert_TokenBurnFromNoBids() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        assertEq(token.ownerOf(2), address(auction));

        vm.warp(10 minutes + 1 seconds);
        auction.settleCurrentAndCreateNewAuction();

        vm.expectRevert(abi.encodeWithSignature("INVALID_OWNER()"));
        token.ownerOf(2);
    }

    function test_OnlySettleWhenPaused() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        vm.prank(bidder1);
        auction.createBid{ value: 0.420 ether }(2);

        vm.prank(bidder2);
        auction.createBid{ value: 1 ether }(2);

        vm.warp(10 minutes + 1 seconds);

        vm.prank(address(treasury));
        auction.pause();

        auction.settleAuction();

        (, , , , , bool settled) = auction.auction();

        assertEq(settled, true);
    }

    function testRevert_CannotOnlySettleWhenNotPaused() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        vm.prank(bidder1);
        auction.createBid{ value: 0.420 ether }(2);

        vm.prank(bidder2);
        auction.createBid{ value: 1 ether }(2);

        vm.warp(10 minutes + 1 seconds);

        vm.expectRevert(abi.encodeWithSignature("UNPAUSED()"));
        auction.settleAuction();
    }

    function test_FirstAuctionPauseAndUnpauseInFirstAuction() public {
        address[] memory wallets = new address[](1);
        uint256[] memory percents = new uint256[](1);
        uint256[] memory vestExpirys = new uint256[](1);

        wallets[0] = address(this);

        deployWithCustomFounders(wallets, percents, vestExpirys);

        vm.prank(address(this));
        auction.unpause();

        vm.prank(bidder1);
        auction.createBid{ value: 0.420 ether }(0);

        vm.startPrank(address(treasury));

        auction.pause();
        auction.unpause();

        vm.stopPrank();

        vm.prank(bidder2);
        auction.createBid{ value: 0.5 ether }(0);
    }

    function test_UpdateDuration() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        vm.prank(address(treasury));
        auction.pause();

        vm.prank(address(treasury));
        auction.setDuration(12 minutes);

        assertEq(auction.duration(), 12 minutes);
    }

    function testRevert_MustBePausedToUpdateDuration() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        vm.prank(address(treasury));
        vm.expectRevert(abi.encodeWithSignature("UNPAUSED()"));
        auction.setDuration(12 minutes);
    }

    function test_UpdateReservePrice() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        vm.prank(address(treasury));
        auction.pause();

        vm.prank(address(treasury));
        auction.setReservePrice(12 ether);

        assertEq(auction.reservePrice(), 12 ether);
    }

    function testRevert_MustBePausedToUpdateReservePrice() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        vm.prank(address(treasury));
        vm.expectRevert(abi.encodeWithSignature("UNPAUSED()"));
        auction.setReservePrice(12 ether);
    }

    function test_UpdateTimeBuffer() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        vm.prank(address(treasury));
        auction.pause();

        vm.prank(address(treasury));
        auction.setTimeBuffer(12 minutes);

        assertEq(auction.timeBuffer(), 12 minutes);
    }

    function testRevert_MustBePausedToUpdateTimeBuffer() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        vm.prank(address(treasury));
        vm.expectRevert(abi.encodeWithSignature("UNPAUSED()"));
        auction.setTimeBuffer(12 minutes);
    }

    function test_UpdateMinBidIncrement() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        vm.prank(address(treasury));
        auction.pause();

        vm.prank(address(treasury));
        auction.setMinimumBidIncrement(12);

        assertEq(auction.minBidIncrement(), 12);
    }

    function testRevert_MustBePausedToUpdateMinBidIncrement() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        vm.prank(address(treasury));
        vm.expectRevert(abi.encodeWithSignature("UNPAUSED()"));
        auction.setMinimumBidIncrement(12);
    }

    function test_UpgradeWhenPaused() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        address owner = manager.owner();

        vm.prank(owner);
        manager.registerUpgrade(auctionImpl, address(mockImpl));

        vm.prank(address(treasury));
        auction.pause();

        vm.prank(address(treasury));
        auction.upgradeTo(address(mockImpl));
    }

    function testRevert_MustUpgradeWhenPaused() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        address owner = manager.owner();

        vm.prank(owner);
        manager.registerUpgrade(auctionImpl, address(mockImpl));

        vm.prank(address(treasury));
        vm.expectRevert(abi.encodeWithSignature("UNPAUSED()"));
        auction.upgradeTo(address(mockImpl));
    }
}
