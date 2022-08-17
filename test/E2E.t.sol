// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {NounsBuilderTest} from "./utils/NounsBuilderTest.sol";

contract E2ETest is NounsBuilderTest {
    address internal bidder1;

    function setUp() public virtual override {
        super.setUp();

        deploy();

        vm.label(address(this), "E2ETEST");

        bidder1 = vm.addr(0xB1);

        vm.label(bidder1, "BIDDER_1");
        vm.deal(bidder1, 100 ether);
    }

    function test_InitialOwnership() public {
        assertEq(token.owner(), founder);
        assertEq(metadataRenderer.owner(), founder);
        assertEq(auction.owner(), founder);

        assertEq(timelock.owner(), address(governor));
        assertEq(governor.owner(), address(timelock));
        assertEq(governor.timelock(), address(timelock));
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function test_FirstAuction() public {
        vm.prank(founder);
        auction.unpause();

        assertEq(token.totalSupply(), 2);
        assertEq(token.ownerOf(0), founder);
        assertEq(token.ownerOf(1), address(auction));

        (uint256 tokenId, , , , , ) = auction.auction();

        assertEq(tokenId, 1);

        vm.prank(bidder1);
        auction.createBid{value: 1 ether}(1);

        (, uint40 duration, , , ) = auction.settings();

        vm.warp(duration + 1 seconds);

        auction.settleCurrentAndCreateNewAuction();

        assertEq(token.ownerOf(1), bidder1);
        assertEq(token.ownerOf(2), address(auction));

        assertEq(address(timelock).balance, 1 ether);
    }

    function test_ProposalVoteQueueExecution() public {
        vm.prank(founder);
        auction.unpause();

        // Create bid
        vm.prank(bidder1);
        auction.createBid{value: 0.420 ether}(1);

        (, uint40 duration, , , ) = auction.settings();

        // Transfer token
        vm.warp(duration + 1 seconds);
        auction.settleCurrentAndCreateNewAuction();

        // Proposal target
        address[] memory targets = new address[](1);
        targets[0] = address(auction);

        // Proposal value
        uint256[] memory values = new uint256[](1);

        // Proposal calldata
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("pause()");

        // Proposal description hash
        bytes32 descriptionHash = keccak256(bytes("hold up"));

        vm.warp(1 days);

        // Propose tx
        vm.prank(bidder1);
        governor.propose(targets, values, calldatas, "hold up");

        // Proposal id
        uint256 proposalId = governor.hashProposal(targets, values, calldatas, descriptionHash);

        // Voting delay
        uint256 votingDelay = governor.votingDelay();
        vm.warp(block.timestamp + votingDelay + 1);

        // Cast vote
        vm.prank(bidder1);
        governor.castVote(proposalId, 1);

        // Voting period
        uint256 votingPeriod = governor.votingPeriod();
        vm.warp(block.timestamp + votingPeriod);

        // Queue tx
        vm.prank(bidder1);
        governor.queue(proposalId);

        // Timelock delay
        vm.warp(block.timestamp + 2 days);

        // Execute tx
        governor.execute(targets, values, calldatas, descriptionHash);

        assertEq(auction.paused(), true);
    }
}
