// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { Test } from "forge-std/Test.sol";
import { Treasury } from "../../src/governance/treasury/Treasury.sol";
import { Auction } from "../../src/auction/Auction.sol";
import { IAuction } from "../../src/auction/IAuction.sol";
import { Token } from "../../src/token/Token.sol";
import { Governor } from "../../src/governance/governor/Governor.sol";
import { IManager } from "../../src/manager/IManager.sol";
import { Manager } from "../../src/manager/Manager.sol";
import { UUPS } from "../../src/lib/proxy/UUPS.sol";

contract TestBidError is Test {
    Manager internal immutable manager = Manager(0xd310A3041dFcF14Def5ccBc508668974b5da7174);
    Token internal immutable token = Token(0x8983eC4B57dbebe8944Af8d4F9D3adBAfEA5b9f1);

    function setUp() public {
        uint256 mainnetFork = vm.createFork(vm.envString("ETH_RPC_MAINNET"));
        vm.selectFork(mainnetFork);
        vm.rollFork(16200201);
    }

    /*

    function testBidIssue() public {
        (address metadata, address auction, address treasury, address governor) = manager.getAddresses(address(token));
        address bidder1 = address(0xb1dd331);
        vm.deal(bidder1, 2 ether);

        vm.expectRevert(IAuction.MINIMUM_BID_NOT_MET.selector);
        vm.prank(bidder1);
        Auction(auction).createBid{ value: 0.1 ether }(2);

        // test new impl
        address newAuctionImpl = address(new Auction(address(manager), address(0)));
        address auctionImpl = manager.auctionImpl();
        // Update bytecode for debugging
        vm.etch(auctionImpl, newAuctionImpl.code);

        vm.prank(bidder1);
        Auction(auction).createBid{ value: 0.10 ether }(2);

        vm.warp(100);

        vm.prank(bidder1);
        Auction(auction).createBid{ value: 0.30 ether }(2);
    }
    */
}
