// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {NounsBuilderTest} from "./utils/NounsBuilderTest.sol";
import {IManager} from "../src/manager/IManager.sol";

contract GovTest is NounsBuilderTest {
    address internal bidder1;

    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed,
        Vetoed
    }

    function setUp() public virtual override {
        super.setUp();

        deploy();

        vm.deal(bidder1, 100 ether);
    }

    function deploy() public override {
        tokenInitStrings = abi.encode(
            "Governor Test Token",
            "GTT",
            "This is a mock governance token",
            "ipfs://Qmew7TdyGnj6YRUjQR68sUJN3239MYXRD8uxowxF6rGK8j",
            "http://localhost:5000/render"
        );

        founderParamsArr.push();
        founderParamsArr.push();

        founderParamsArr[0] = IManager.FounderParams({wallet: founder, allocationFrequency: 5, vestingEnd: 4 weeks});
        founderParamsArr[1] = IManager.FounderParams({wallet: address(this), allocationFrequency: 10, vestingEnd: 4 weeks});

        tokenParams = IManager.TokenParams({initStrings: tokenInitStrings});

        auctionParams = IManager.AuctionParams({reservePrice: 0 ether, duration: 1 days});

        govParams = IManager.GovParams({
            timelockDelay: 2 days,
            votingDelay: 1 days,
            votingPeriod: 1 weeks,
            proposalThresholdBPS: 25,
            quorumVotesBPS: 1000
        });

        deploy(founderParamsArr, tokenParams, auctionParams, govParams);
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function test_GovernorInit() public {
        assertEq(governor.owner(), address(timelock));
        assertEq(governor.timelock(), address(timelock));
        assertEq(governor.token(), address(token));
        assertEq(governor.vetoer(), address(founder));

        assertEq(governor.votingDelay(), govParams.votingDelay);
        assertEq(governor.votingPeriod(), govParams.votingPeriod);
        assertEq(governor.proposalThresholdBps(), govParams.proposalThresholdBPS);
        assertEq(governor.quorumVotesBps(), govParams.quorumVotesBPS);
    }

    function test_TimelockInit() public {
        assertEq(timelock.owner(), address(governor));
        assertEq(timelock.delay(), govParams.timelockDelay);
    }

    function testRevert_CannotReinitializeGovernor() public {
        vm.expectRevert(abi.encodeWithSignature("ALREADY_INITIALIZED()"));
        governor.initialize(address(this), address(this), address(this), 0, 0, 0, 0);
    }

    function testRevert_CannotReinitializeTimelock() public {
        vm.expectRevert(abi.encodeWithSignature("ALREADY_INITIALIZED()"));
        timelock.initialize(address(this), 0);
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function mintToken() internal {
        vm.prank(founder);
        auction.unpause();

        vm.prank(bidder1);
        auction.createBid{value: 0.420 ether}(1);

        vm.warp(auctionParams.duration + 1 seconds);
        auction.settleCurrentAndCreateNewAuction();
    }

    function fastForwardAuction(
        address _bidder,
        uint256 _bid,
        uint256 _numAuctions
    ) internal {
        vm.deal(_bidder, _bid);

        vm.prank(founder);
        auction.unpause();

        for (uint256 i; i < _numAuctions; i++) {
            (uint256 tokenId, , , , , ) = auction.auction();

            vm.prank(_bidder);
            auction.createBid{value: _bid}(tokenId);

            vm.warp(auctionParams.duration + 1 seconds);
            auction.settleCurrentAndCreateNewAuction();
        }
    }

    function test_CreateProposal() public {
        mintToken();

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(auction);
        calldatas[0] = abi.encodeWithSignature("pause()");

        bytes32 descriptionHash = keccak256(bytes("hold up"));

        uint256 hashedProposalId = governor.hashProposal(targets, values, calldatas, descriptionHash);

        vm.prank(bidder1);
        uint256 returnedProposalId = governor.propose(targets, values, calldatas, "hold up");

        assertEq(hashedProposalId, returnedProposalId);

        (address proposer, , , , uint256 voteStart, uint256 voteEnd, uint256 proposalThreshold, uint256 quorumVotes, , , ) = governor.proposals(
            hashedProposalId
        );

        assertEq(proposer, bidder1);

        assertEq(voteStart, block.timestamp + governor.votingDelay());
        assertEq(voteEnd, block.timestamp + governor.votingDelay() + governor.votingPeriod());

        assertEq(proposalThreshold, (token.totalSupply() * governor.proposalThresholdBps()) / 10_000);
        assertEq(quorumVotes, (token.totalSupply() * governor.quorumVotesBps()) / 10_000);

        assertEq(uint256(governor.state(hashedProposalId)), uint256(ProposalState.Pending));

        assertEq(timelock.hashProposal(targets, values, calldatas, descriptionHash), hashedProposalId);
    }

    function testRevert_NoTarget() public {
        mintToken();

        address[] memory targets;
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        calldatas[0] = abi.encodeWithSignature("pause()");

        vm.expectRevert(abi.encodeWithSignature("NO_TARGET_PROVIDED()"));
        governor.propose(targets, values, calldatas, "hold up");
    }

    function testRevert_NoValue() public {
        mintToken();

        address[] memory targets = new address[](1);
        uint256[] memory values;
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(auction);
        calldatas[0] = abi.encodeWithSignature("pause()");

        vm.expectRevert(abi.encodeWithSignature("INVALID_PROPOSAL_LENGTH()"));
        governor.propose(targets, values, calldatas, "hold up");
    }

    function testRevert_NoCalldata() public {
        mintToken();

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas;

        targets[0] = address(auction);

        vm.expectRevert(abi.encodeWithSignature("INVALID_PROPOSAL_LENGTH()"));
        governor.propose(targets, values, calldatas, "hold up");
    }

    function testRevert_ProposalExists() public {
        mintToken();

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(auction);
        calldatas[0] = abi.encodeWithSignature("pause()");

        bytes32 descriptionHash = keccak256(bytes("hold up"));

        uint256 proposalId = governor.hashProposal(targets, values, calldatas, descriptionHash);

        governor.propose(targets, values, calldatas, "hold up");

        vm.expectRevert(abi.encodeWithSignature("PROPOSAL_EXISTS(uint256)", proposalId));
        governor.propose(targets, values, calldatas, "hold up");
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function test_CastVoteWithWeight() public {
        // hasVoted = true
        // proposalVotes changes
        // state changes
    }

    function test_CastVoteWithoutWeight() public {
        // hasVoted = true
        // no proposalVotes changes
    }

    function testRevert_CannotVoteOnInactiveProposal() public {}

    function testRevert_CannotVoteTwice() public {}

    function testRevert_InvalidVote() public {}

    function test_CastVoteWithSig() public {}

    function testRevert_InvalidVoteSig() public {}

    function testRevert_InvalidVoteNonce() public {}

    function testRevert_InvalidVoteExpired() public {}

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function test_CancelProposal() public {}

    function test_CancelProposalAndTimelock() public {}

    function test_CancelSinceProposerFellBelowThreshold() public {}

    function testRevert_CannotCancelAlreadyExecuted() public {}

    function testRevert_ProposerAboveThreshold() public {}

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function test_VetoProposal() public {}

    function testRevert_CallerNotVetoer() public {}

    function testRevert_CannotVetoExecuted() public {}

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function test_QueueProposal() public {}

    function testRevert_CannotQueueFailed() public {}

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function test_ExecuteProposal() public {}

    function testRevert_NotQueuedForExecution() public {}

    function testRevert_IncorrectValueAttached() public {}

    /// ...

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    /// update all settings -- reverts if not called by gov

    /**
  
 

        Create Proposal
        - rejects if below proposal threshold

        - proposalCount 

        - proposal threshold is accurate based on token supply
        - quorum votes is accurate based on token supply


        - _getVotes weight is retreived correctly from token
        - correct support category is updated (abstain vs for vs against)
        - hasVoted is marked as true


        Cancel Proposal
        - reverts if proposal was executed
        - reverts if caller is not proposer
        - reverts if proposer weight is now under the threshold it was when it created the proposal

        - marks the proposal as canceled
        - ^ this should be reflected in state()
        - cancels the operation on the timelock
        - deletes timelockIds[_proposalId]

        Veto Proposal
        - marks the proposal as vetoed
        - cancels the operation on the timelock
        - deletes timelockIds[_proposalId]

        Queue Proposal
        - rejects if proposal is not successful
        - correctly stores the result of timelock.scheduleBatch in timestampIds[]

        Execute Proposal
        - reverts if state is not queued
        - reverts if incorrect amount of ETH was attached

        - marks the proposal as executed
        - executes the timelock operation

        State
        - rejects if proposal doesn't exist

        -

        Settings
        - update timelock
            - reverts if caller is not timelock
        - update vetoer
            - reverts if caller is not timelock
        - update ALL vars
            - reverts if unsafe cast

        Contract Upgrade?
        - upgrades impl?

     */

    /**
        Init
        - all params are saved correctly
        - ownable is setup correctly
        
        schedule + scheduleBatch
        - reverts if arr length mismatch
        - reverts if operation already exists
        - reverts if invalid delay
        - stores the correct operation time in timestamps[_operationId]

        cancel
        - reverts if operation is not pending
        - deletes timestamps[_operationId]
        - check if state() in governor is updated correctly

        execute + executeBatch
        - reverts if length mismatch
        - reverts if operation is not ready
        - reverts if predecessor is not done (if batch)
        - reverts if msg.value was not enough and TX reverts
        
        - isOperationDone is true
        - state() in governor is reflected

        updateMinDelay
        - reverts if caller is not timelock

        contractUpgrade?
     */
}
