// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import { NounsBuilderTest } from "./utils/NounsBuilderTest.sol";

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

    // function test_InitialOwnership() public {
    //     assertEq(token.owner(), founder);
    //     assertEq(metadataRenderer.owner(), founder);
    //     assertEq(auction.owner(), founder);

    //     assertEq(treasury.owner(), address(governor));
    //     assertEq(governor.owner(), address(treasury));
    //     assertEq(governor.treasury(), address(treasury));
    // }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    // function test_FirstAuction() public {
    //     vm.prank(founder);
    //     auction.unpause();

    //     assertEq(token.totalSupply(), 3);
    //     // assertEq(token.ownerOf(0), founder);
    //     // assertEq(token.ownerOf(1), founder2);

    //     // (uint256 tokenId, , , , , ) = auction.auction();

    //     // assertEq(tokenId, 2);

    //     vm.prank(bidder1);
    //     auction.createBid{ value: 1 ether }(2);

    //     uint256 duration = auction.duration();

    //     vm.warp(duration + 1 seconds);

    //     auction.settleCurrentAndCreateNewAuction();

    //     assertEq(token.ownerOf(2), bidder1);
    //     assertEq(token.ownerOf(3), address(auction));

    //     assertEq(address(treasury).balance, 1 ether);
    // }

    function test_ProposalVoteQueueExecution() public {
        vm.prank(founder);
        auction.unpause();

        // Create bid
        vm.prank(bidder1);
        auction.createBid{ value: 0.420 ether }(2);

        uint256 duration = auction.duration();

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
        bytes32 proposalId = governor.hashProposal(targets, values, calldatas, descriptionHash);

        // Voting delay
        vm.warp(block.timestamp + governor.votingDelay());

        // Cast vote
        vm.prank(bidder1);
        governor.castVote(proposalId, 1);

        // Voting period
        vm.warp(block.timestamp + governor.votingPeriod());

        // Queue tx
        vm.prank(bidder1);
        governor.queue(proposalId);

        // Treasury delay
        vm.warp(block.timestamp + 2 days);

        // Execute tx
        governor.execute(targets, values, calldatas, descriptionHash);

        assertEq(auction.paused(), true);
    }
}
