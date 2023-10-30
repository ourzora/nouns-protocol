// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { NounsBuilderTest } from "./utils/NounsBuilderTest.sol";
import { MockERC721 } from "./utils/mocks/MockERC721.sol";
import { MockImpl } from "./utils/mocks/MockImpl.sol";
import { MockPartialTokenImpl } from "./utils/mocks/MockPartialTokenImpl.sol";
import { MockProtocolRewards } from "./utils/mocks/MockProtocolRewards.sol";
import { Auction } from "../src/auction/Auction.sol";
import { IAuction } from "../src/auction/IAuction.sol";
import { AuctionTypesV2 } from "../src/auction/types/AuctionTypesV2.sol";

contract AuctionTest is NounsBuilderTest {
    MockImpl internal mockImpl;
    Auction internal rewardImpl;

    address internal bidder1;
    address internal bidder2;
    address internal referral;

    uint16 internal builderRewardBPS = 300;
    uint16 internal referralRewardBPS = 400;

    function setUp() public virtual override {
        super.setUp();

        bidder1 = vm.addr(0xB1);
        bidder2 = vm.addr(0xB2);

        referral = vm.addr(0x41);

        vm.deal(bidder1, 100 ether);
        vm.deal(bidder2, 100 ether);

        mockImpl = new MockImpl();
        rewardImpl = new Auction(address(manager), address(rewards), weth, builderRewardBPS, referralRewardBPS);
    }

    function deployAltMock(address founderRewardRecipent, uint16 founderRewardPercent) internal virtual {
        setMockFounderParams();

        setMockTokenParams();

        setAuctionParams(0.01 ether, 10 minutes, founderRewardRecipent, founderRewardPercent);

        setMockGovParams();

        deploy(foundersArr, tokenParams, auctionParams, govParams);

        setMockMetadata();
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
        auction.initialize(address(token), address(this), address(treasury), 1 minutes, 0 ether, address(0), 0);
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

    function test_ZeroBidIncrementNotAllowed() public {
        deployMock();

        vm.prank(founder);
        vm.expectRevert(IAuction.MIN_BID_INCREMENT_1_PERCENT.selector);
        auction.setMinimumBidIncrement(0);
    }

    function test_CreateMultipleBidsAfterZero(uint256 _amount) public {
        deployMock();
        vm.assume(_amount > 0 && _amount <= bidder1.balance);

        vm.startPrank(founder);
        // Set minimum possible bid increment
        auction.setMinimumBidIncrement(1);
        auction.setReservePrice(0);

        auction.unpause();
        vm.stopPrank();

        vm.prank(bidder1);

        // 0 value bid placed
        auction.createBid{ value: 0 }(2);

        (, uint256 highestBidOriginal, address highestBidderOriginal, , , ) = auction.auction();
        assertEq(highestBidOriginal, 0);
        assertEq(highestBidderOriginal, bidder1);

        uint256 bidder2BalanceBefore = bidder2.balance;

        vm.prank(bidder2);
        auction.createBid{ value: _amount }(2);

        (, uint256 highestBid, address highestBidder, , , ) = auction.auction();
        assertEq(highestBid, _amount);
        assertEq(highestBidder, bidder2);
        assertEq(bidder2BalanceBefore - bidder2.balance, _amount);
    }

    function test_NoTwoZeroValueBids() public {
        deployMock();

        // Set minimum possible bid increment
        vm.startPrank(founder);
        auction.setMinimumBidIncrement(1);
        auction.setReservePrice(0);
        vm.stopPrank();

        vm.prank(founder);
        auction.unpause();

        // 0 value bid placed
        vm.prank(bidder1);
        auction.createBid{ value: 0 }(2);

        // another 0 value bid should not be able to be
        vm.prank(bidder2);
        vm.expectRevert(IAuction.MINIMUM_BID_NOT_MET.selector);
        auction.createBid{ value: 0 }(2);
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

    function testRevert_CannotBidZeroWithZeroBid() public {
        deployMock();

        vm.prank(founder);
        auction.setReservePrice(0);

        vm.prank(founder);
        auction.unpause();

        vm.prank(bidder1);
        auction.createBid{ value: 0 ether }(2);

        vm.warp(5 minutes);

        vm.prank(bidder2);
        vm.expectRevert(abi.encodeWithSignature("MINIMUM_BID_NOT_MET()"));
        auction.createBid{ value: 0 ether }(2);
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

    function testRevert_AuctionFailedTokenMintOnCreate() public {
        deployMock();

        MockPartialTokenImpl mockTokenFailingImpl = new MockPartialTokenImpl();

        vm.prank(zoraDAO);
        manager.registerUpgrade(tokenImpl, address(mockTokenFailingImpl));

        // Upgrade token to invalid contract
        vm.prank(address(founder));
        token.upgradeTo(address(mockTokenFailingImpl));

        vm.prank(founder);
        vm.expectRevert(abi.encodeWithSignature("AUCTION_CREATE_FAILED_TO_LAUNCH()"));
        auction.unpause();

        assertTrue(auction.paused());
        assertEq(auction.owner(), founder);
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

    function test_FounderRewardSet() public {
        // deploy with 5% founder fee
        deployAltMock(founder, 500);

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

        assertEq(address(treasury).balance, 0.95 ether);
    }

    function test_UpdateFounderReward() public {
        // deploy with 5% founder fee
        deployAltMock(founder, 500);

        (address recipient, uint256 percentBps) = auction.founderReward();

        assertEq(recipient, founder);
        assertEq(percentBps, 500);

        AuctionTypesV2.FounderReward memory newRewards = AuctionTypesV2.FounderReward({ recipient: founder2, percentBps: 1000 });

        vm.prank(founder);
        auction.setFounderReward(newRewards);

        (address newRecipient, uint256 newPercentBps) = auction.founderReward();

        assertEq(newRecipient, founder2);
        assertEq(newPercentBps, 1000);
    }

    function testRevert_DeployInvalidBPS() public {
        setMockFounderParams();

        setMockTokenParams();

        setAuctionParams(0.01 ether, 10 minutes, founder, 4_000);

        setMockGovParams();

        vm.expectRevert(abi.encodeWithSignature("INVALID_REWARDS_BPS()"));
        deploy(foundersArr, tokenParams, auctionParams, govParams);
    }

    function testRevert_DeployInvalidRecipient() public {
        setMockFounderParams();

        setMockTokenParams();

        setAuctionParams(0.01 ether, 10 minutes, address(0), 1_000);

        setMockGovParams();

        vm.expectRevert(abi.encodeWithSignature("INVALID_REWARDS_RECIPIENT()"));
        deploy(foundersArr, tokenParams, auctionParams, govParams);
    }

    function testRevert_UpdateFounderRewardInvalidConfig() public {
        // deploy with 5% founder fee
        deployAltMock(founder, 500);

        (address recipient, uint256 percentBps) = auction.founderReward();

        assertEq(recipient, founder);
        assertEq(percentBps, 500);

        AuctionTypesV2.FounderReward memory newRewards = AuctionTypesV2.FounderReward({ recipient: founder2, percentBps: 4_000 });

        vm.prank(founder);
        vm.expectRevert(abi.encodeWithSignature("INVALID_REWARDS_BPS()"));
        auction.setFounderReward(newRewards);
    }

    function test_BuilderAndReferralReward() external {
        // Setup
        deployMock();

        vm.prank(manager.owner());
        manager.registerUpgrade(auctionImpl, address(rewardImpl));

        vm.prank(auction.owner());
        auction.upgradeTo(address(rewardImpl));

        vm.prank(founder);
        auction.unpause();

        // Check reward values

        vm.prank(bidder1);
        auction.createBidWithReferral{ value: 1 ether }(2, referral);

        vm.warp(10 minutes + 1 seconds);

        auction.settleCurrentAndCreateNewAuction();

        assertEq(token.ownerOf(2), bidder1);
        assertEq(token.getVotes(bidder1), 1);

        assertEq(address(treasury).balance, 0.93 ether);
        assertEq(address(rewards).balance, 0.03 ether + 0.04 ether);

        assertEq(MockProtocolRewards(rewards).balanceOf(zoraDAO), 0.03 ether);
        assertEq(MockProtocolRewards(rewards).balanceOf(referral), 0.04 ether);
    }

    function test_FounderBuilderAndReferralReward() external {
        // Setup
        deployAltMock(founder, 500);

        vm.prank(manager.owner());
        manager.registerUpgrade(auctionImpl, address(rewardImpl));

        vm.prank(auction.owner());
        auction.upgradeTo(address(rewardImpl));

        vm.prank(founder);
        auction.unpause();

        // Check reward values

        vm.prank(bidder1);
        auction.createBidWithReferral{ value: 1 ether }(2, referral);

        vm.warp(10 minutes + 1 seconds);

        auction.settleCurrentAndCreateNewAuction();

        assertEq(token.ownerOf(2), bidder1);
        assertEq(token.getVotes(bidder1), 1);

        assertEq(address(treasury).balance, 0.88 ether);
        assertEq(address(rewards).balance, 0.03 ether + 0.04 ether + 0.05 ether);

        assertEq(MockProtocolRewards(rewards).balanceOf(zoraDAO), 0.03 ether);
        assertEq(MockProtocolRewards(rewards).balanceOf(referral), 0.04 ether);
        assertEq(MockProtocolRewards(rewards).balanceOf(founder), 0.05 ether);
    }
}
