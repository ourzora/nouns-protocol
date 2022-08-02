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
        assertEq(token.owner(), treasuryAddress);
        assertEq(metadataRenderer.owner(), treasuryAddress);

        assertEq(auction.owner(), foundersDAO);

        assertEq(treasury.hasRole(treasury.TIMELOCK_ADMIN_ROLE(), address(governor)), true);
        assertEq(treasury.hasRole(treasury.TIMELOCK_ADMIN_ROLE(), address(deployer)), false);

        assertEq(governor.owner(), address(treasury));
        assertEq(governor.timelock(), address(treasury));
    }

    function test_FirstAuction() public {
        vm.prank(foundersDAO);
        auction.unpause();

        assertEq(token.totalSupply(), 2);
        assertEq(token.ownerOf(0), foundersDAO);
        assertEq(token.ownerOf(1), address(auction));
        assertEq(auction.auction().tokenId, 1);

        vm.prank(bidder1);
        auction.createBid{value: 0.420 ether}(1);

        vm.warp(auction.house().duration + 1 seconds);

        auction.settleCurrentAndCreateNewAuction();

        assertEq(token.ownerOf(1), bidder1);
        assertEq(token.ownerOf(2), address(auction));

        assertEq(nounsDAO.balance, 0.0042 ether); // 1% Nouns
        assertEq(nounsBuilderDAO.balance, 0.0042 ether); // 1% Nouns Builder
        assertEq(address(treasury).balance, 0.4116 ether); // 98% Treasury
    }

    function test_ProposalVoteQueueExecution() public {
        vm.prank(foundersDAO);
        auction.unpause();

        // Create bid
        vm.prank(bidder1);
        auction.createBid{value: 0.420 ether}(1);

        // Transfer token
        vm.warp(auction.house().duration + 1 seconds);
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
        bytes32 descriptionHash = keccak256(bytes("hol up"));

        // Propose tx
        vm.prank(bidder1);
        governor.propose(targets, values, calldatas, "hol up");

        // Proposal id
        uint256 proposalId = governor.hashProposal(targets, values, calldatas, descriptionHash);

        // Voting delay
        uint256 votingDelay = governor.votingDelay();
        vm.roll(block.number + votingDelay + 1);

        // Cast vote
        vm.prank(bidder1);
        governor.castVote(proposalId, 1);

        // Voting period
        uint256 votingPeriod = governor.votingPeriod();
        vm.roll(block.number + votingPeriod);

        // Queue tx
        vm.prank(bidder1);
        governor.queue(targets, values, calldatas, descriptionHash);

        // Timelock delay
        vm.warp(block.timestamp + 2 days);

        // Execute tx
        governor.execute(targets, values, calldatas, descriptionHash);

        assertEq(auction.paused(), true);
    }
}
