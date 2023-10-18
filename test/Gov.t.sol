// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { NounsBuilderTest } from "./utils/NounsBuilderTest.sol";

import { IManager } from "../src/manager/IManager.sol";
import { IGovernor } from "../src/governance/governor/IGovernor.sol";
import { GovernorTypesV1 } from "../src/governance/governor/types/GovernorTypesV1.sol";

contract GovTest is NounsBuilderTest, GovernorTypesV1 {
    uint256 internal constant AGAINST = 0;
    uint256 internal constant FOR = 1;
    uint256 internal constant ABSTAIN = 2;

    address internal voter1;
    uint256 internal voter1PK;
    address internal voter2;
    uint256 internal voter2PK;

    IManager.GovParams internal altGovParams;

    function setUp() public virtual override {
        super.setUp();

        createVoter1();
        createVoter2();
    }

    function deployMock() internal override {
        address[] memory wallets = new address[](2);
        uint256[] memory percents = new uint256[](2);
        uint256[] memory vestingEnd = new uint256[](2);

        wallets[0] = founder;
        wallets[1] = founder2;

        percents[0] = 1;
        percents[1] = 1;

        vestingEnd[0] = 4 weeks;
        vestingEnd[1] = 4 weeks;

        setFounderParams(wallets, percents, vestingEnd);

        setMockTokenParams();

        setAuctionParams(0, 1 days, address(0), 0);

        setGovParams(2 days, 1 days, 1 weeks, 25, 1000, founder);

        deploy(foundersArr, tokenParams, auctionParams, govParams);

        setMockMetadata();
    }

    function deployAltMock() internal {
        address[] memory wallets = new address[](2);
        uint256[] memory percents = new uint256[](2);
        uint256[] memory vestingEnd = new uint256[](2);

        wallets[0] = founder;
        wallets[1] = founder2;

        percents[0] = 1;
        percents[1] = 1;

        vestingEnd[0] = 4 weeks;
        vestingEnd[1] = 4 weeks;

        setFounderParams(wallets, percents, vestingEnd);

        setMockTokenParams();

        setAuctionParams(0, 1 days, address(0), 0);

        setGovParams(2 days, 1 days, 1 weeks, 100, 1000, founder);

        deploy(foundersArr, tokenParams, auctionParams, govParams);

        setMockMetadata();
    }

    function createVoter1() internal {
        voter1PK = 0xABE;
        voter1 = vm.addr(voter1PK);

        vm.deal(voter1, 100 ether);
    }

    function createVoter2() internal {
        voter2PK = 0xBAE;
        voter2 = vm.addr(voter2PK);

        vm.deal(voter2, 100 ether);
    }

    function mintVoter1() internal {
        vm.prank(founder);
        auction.unpause();

        vm.prank(voter1);
        auction.createBid{ value: 0.420 ether }(2);

        vm.warp(block.timestamp + auctionParams.duration + 1 seconds);
        auction.settleCurrentAndCreateNewAuction();
        vm.warp(block.timestamp + 20);
    }

    function mintVoter2() internal {
        vm.prank(voter2);
        auction.createBid{ value: 0.420 ether }(3);

        vm.warp(block.timestamp + auctionParams.duration + 1 seconds);
        auction.settleCurrentAndCreateNewAuction();
        vm.warp(block.timestamp + 20);
    }

    function castVotes(
        bytes32 _proposalId,
        uint256 _numAgainst,
        uint256 _numFor,
        uint256 _numAbstain
    ) internal {
        uint256 currentVoterIndex;

        for (uint256 i = 0; i < _numAgainst; ++i) {
            vm.prank(otherUsers[currentVoterIndex]);
            governor.castVote(_proposalId, AGAINST);

            ++currentVoterIndex;
        }

        for (uint256 i = 0; i < _numFor; ++i) {
            vm.prank(otherUsers[currentVoterIndex]);
            governor.castVote(_proposalId, FOR);

            ++currentVoterIndex;
        }

        for (uint256 i = 0; i < _numAbstain; ++i) {
            vm.prank(otherUsers[currentVoterIndex]);
            governor.castVote(_proposalId, ABSTAIN);

            ++currentVoterIndex;
        }
    }

    function mockProposal()
        internal
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        )
    {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);

        targets[0] = address(auction);
        calldatas[0] = abi.encodeWithSignature("pause()");
    }

    function createProposal() internal returns (bytes32 proposalId) {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = mockProposal();

        vm.startPrank(address(auction));
        uint256 newTokenId = token.mint();
        token.transferFrom(address(auction), voter1, newTokenId);
        vm.stopPrank();

        vm.prank(address(treasury));
        governor.updateProposalThresholdBps(1);

        vm.warp(block.timestamp + 20);

        vm.prank(voter1);
        proposalId = governor.propose(targets, values, calldatas, "");
    }

    function createProposal(
        address _proposer,
        address _target,
        uint256 _value,
        bytes memory _calldata
    ) internal returns (bytes32 proposalId) {
        deployMock();

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = _target;
        values[0] = _value;
        calldatas[0] = _calldata;

        vm.prank(_proposer);
        proposalId = governor.propose(targets, values, calldatas, "");
    }

    function test_GovernorInit() public {
        deployMock();

        assertEq(governor.owner(), address(treasury));
        assertEq(governor.treasury(), address(treasury));
        assertEq(governor.token(), address(token));
        assertEq(governor.vetoer(), address(founder));

        assertEq(governor.votingDelay(), govParams.votingDelay);
        assertEq(governor.votingPeriod(), govParams.votingPeriod);
        assertEq(governor.proposalThresholdBps(), govParams.proposalThresholdBps);
        assertEq(governor.quorumThresholdBps(), govParams.quorumThresholdBps);
    }

    function test_TreasuryInit() public {
        deployMock();

        assertEq(treasury.owner(), address(governor));
        assertEq(treasury.delay(), govParams.timelockDelay);
    }

    function testRevert_CannotReinitializeGovernor() public {
        deployMock();

        vm.expectRevert(abi.encodeWithSignature("ALREADY_INITIALIZED()"));
        governor.initialize(address(this), address(this), address(this), 0, 0, 0, 0);
    }

    function testRevert_CannotReinitializeTreasury() public {
        deployMock();

        vm.expectRevert(abi.encodeWithSignature("ALREADY_INITIALIZED()"));
        treasury.initialize(address(this), 0);
    }

    function test_CreateProposal() public {
        deployMock();

        mintVoter1();

        vm.prank(address(treasury));
        governor.updateProposalThresholdBps(1);

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = mockProposal();

        bytes32 descriptionHash = keccak256(bytes(""));
        bytes32 proposalId = governor.hashProposal(targets, values, calldatas, descriptionHash, voter1);

        vm.prank(voter1);
        bytes32 returnedProposalId = governor.propose(targets, values, calldatas, "");

        assertEq(proposalId, returnedProposalId);

        Proposal memory proposal = governor.getProposal(proposalId);

        assertEq(proposal.proposer, voter1);

        assertEq(proposal.voteStart, block.timestamp + governor.votingDelay());
        assertEq(proposal.voteEnd, block.timestamp + governor.votingDelay() + governor.votingPeriod());

        assertEq(proposal.voteStart, governor.proposalSnapshot(proposalId));
        assertEq(proposal.voteEnd, governor.proposalDeadline(proposalId));

        assertEq(proposal.proposalThreshold, (token.totalSupply() * governor.proposalThresholdBps()) / 10_000);
        assertEq(proposal.quorumVotes, (token.totalSupply() * governor.quorumThresholdBps()) / 10_000);

        assertEq(uint256(governor.state(proposalId)), uint256(ProposalState.Pending));

        assertEq(treasury.hashProposal(targets, values, calldatas, descriptionHash, voter1), proposalId);
    }

    /// @notice Test that a proposal cannot be front-run and canceled by a malicious user
    function test_ProposalHashUniqueToSender() public {
        deployMock();

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = mockProposal();

        bytes32 descriptionHash = keccak256(bytes(""));
        bytes32 proposalId1 = governor.hashProposal(targets, values, calldatas, descriptionHash, voter1);
        bytes32 proposalId2 = governor.hashProposal(targets, values, calldatas, descriptionHash, voter2);

        assertTrue(proposalId1 != proposalId2);
    }

    function test_VerifySubmittedProposalHash() public {
        deployMock();

        // Mint a token to voter 1 to have quorum
        mintVoter1();

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = mockProposal();

        vm.prank(voter1);
        bytes32 proposalId = governor.propose(targets, values, calldatas, "");

        assertEq(proposalId, governor.hashProposal(targets, values, calldatas, keccak256(bytes("")), voter1));
    }

    function testFail_MismatchingHashesFromIncorrectProposer() public {
        deployMock();

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = mockProposal();

        vm.prank(voter1);
        bytes32 proposalId = governor.propose(targets, values, calldatas, "");

        bytes32 incorrectProposalId = governor.hashProposal(targets, values, calldatas, keccak256(bytes("")), address(this));

        assertEq(proposalId, incorrectProposalId);
    }

    function testRevert_NoTarget() public {
        deployMock();

        mintVoter1();

        address[] memory targets;
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        calldatas[0] = abi.encodeWithSignature("pause()");

        vm.expectRevert(abi.encodeWithSignature("PROPOSAL_TARGET_MISSING()"));
        vm.prank(voter1);
        governor.propose(targets, values, calldatas, "");
    }

    function testRevert_NoValue() public {
        deployMock();

        mintVoter1();

        address[] memory targets = new address[](1);
        uint256[] memory values;
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(auction);
        calldatas[0] = abi.encodeWithSignature("pause()");

        vm.expectRevert(abi.encodeWithSignature("PROPOSAL_LENGTH_MISMATCH()"));
        vm.prank(voter1);
        governor.propose(targets, values, calldatas, "");
    }

    function testRevert_NoCalldata() public {
        deployMock();

        mintVoter1();

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas;

        targets[0] = address(auction);

        vm.expectRevert(abi.encodeWithSignature("PROPOSAL_LENGTH_MISMATCH()"));
        vm.prank(voter1);
        governor.propose(targets, values, calldatas, "");
    }

    function testRevert_ProposalExists() public {
        deployMock();

        mintVoter1();

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(auction);
        calldatas[0] = abi.encodeWithSignature("pause()");

        bytes32 descriptionHash = keccak256(bytes(""));

        vm.startPrank(voter1);
        bytes32 proposalId = governor.hashProposal(targets, values, calldatas, descriptionHash, voter1);
        governor.propose(targets, values, calldatas, "");

        vm.expectRevert(abi.encodeWithSignature("PROPOSAL_EXISTS(bytes32)", proposalId));
        governor.propose(targets, values, calldatas, "");
        vm.stopPrank();
    }

    function testRevert_BelowProposalThreshold(uint32 bps) public {
        vm.assume(bps < 1000 && bps > 0);
        deployMock();

        mintVoter1();

        vm.prank(address(treasury));
        governor.updateProposalThresholdBps(bps);

        // Go back in time before voter1 token is minted
        vm.warp(1);

        assertEq(governor.proposalThreshold(), 0);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(auction);
        calldatas[0] = abi.encodeWithSignature("");

        for (uint256 i; i < 11; ++i) {
            vm.prank(address(auction));
            token.mint();
        }

        vm.expectRevert(abi.encodeWithSignature("BELOW_PROPOSAL_THRESHOLD()"));
        vm.prank(voter1);
        governor.propose(targets, values, calldatas, "");
    }

    function test_CastVote() public {
        deployMock();

        // This mints a token to voter1
        bytes32 proposalId = createProposal();

        uint256 votingDelay = governor.votingDelay();
        vm.warp(block.timestamp + votingDelay + 1);

        assertEq(uint256(governor.state(proposalId)), uint256(ProposalState.Active));

        vm.prank(voter1);
        governor.castVote(proposalId, FOR);

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);

        assertEq(againstVotes, 0);
        assertEq(forVotes, 1);
        assertEq(abstainVotes, 0);
    }

    function test_CastVoteWithoutWeight() public {
        deployMock();

        mintVoter1();

        bytes32 proposalId = createProposal();

        vm.warp(block.timestamp + governor.votingDelay());

        governor.castVote(proposalId, FOR);

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);

        assertEq(againstVotes, 0);
        assertEq(forVotes, 0);
        assertEq(abstainVotes, 0);
    }

    function test_CastVoteWithSig() public {
        deployMock();

        // This mints a token to voter1
        bytes32 proposalId = createProposal();

        uint256 votingDelay = governor.votingDelay();
        vm.warp(block.timestamp + votingDelay + 1);

        bytes32 domainSeparator = governor.DOMAIN_SEPARATOR();
        bytes32 voteTypeHash = governor.VOTE_TYPEHASH();
        uint256 voterNonce = governor.nonce(voter1);
        uint256 deadline = governor.proposalDeadline(proposalId);

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, keccak256(abi.encode(voteTypeHash, voter1, proposalId, FOR, voterNonce, deadline)))
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(voter1PK, digest);
        governor.castVoteBySig(voter1, proposalId, FOR, deadline, v, r, s);

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);

        assertEq(againstVotes, 0);
        assertEq(forVotes, 1);
        assertEq(abstainVotes, 0);
    }

    function testRevert_VotingNotStarted() public {
        deployMock();

        mintVoter1();

        bytes32 proposalId = createProposal();

        vm.expectRevert(abi.encodeWithSignature("VOTING_NOT_STARTED()"));
        vm.prank(voter1);
        governor.castVote(proposalId, FOR);
    }

    function testRevert_CannotVoteTwice() public {
        deployMock();

        mintVoter1();

        bytes32 proposalId = createProposal();

        uint256 votingDelay = governor.votingDelay();
        vm.warp(block.timestamp + votingDelay + 1);

        vm.prank(voter1);
        governor.castVote(proposalId, FOR);

        vm.prank(voter1);
        vm.expectRevert(abi.encodeWithSignature("ALREADY_VOTED()"));
        governor.castVote(proposalId, FOR);
    }

    function testRevert_InvalidVoteType() public {
        deployMock();

        mintVoter1();

        bytes32 proposalId = createProposal();

        uint256 votingDelay = governor.votingDelay();
        vm.warp(block.timestamp + votingDelay + 1);

        vm.expectRevert(abi.encodeWithSignature("INVALID_VOTE()"));
        governor.castVote(proposalId, 3);
    }

    function testRevert_InvalidVoteSigner() public {
        deployMock();

        mintVoter1();

        bytes32 proposalId = createProposal();

        uint256 votingDelay = governor.votingDelay();
        vm.warp(block.timestamp + votingDelay + 1);

        bytes32 domainSeparator = governor.DOMAIN_SEPARATOR();
        bytes32 voteTypeHash = governor.VOTE_TYPEHASH();
        uint256 voterNonce = governor.nonce(voter1);
        uint256 deadline = governor.proposalDeadline(proposalId);

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, keccak256(abi.encode(voteTypeHash, voter1, proposalId, FOR, voterNonce, deadline)))
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xF, digest);

        vm.expectRevert(abi.encodeWithSignature("INVALID_SIGNATURE()"));
        governor.castVoteBySig(voter1, proposalId, FOR, deadline, v, r, s);
    }

    function testRevert_InvalidVoteNonce() public {
        deployMock();

        mintVoter1();

        bytes32 proposalId = createProposal();

        uint256 votingDelay = governor.votingDelay();
        vm.warp(block.timestamp + votingDelay + 1);

        bytes32 domainSeparator = governor.DOMAIN_SEPARATOR();
        bytes32 voteTypeHash = governor.VOTE_TYPEHASH();
        uint256 voterNonce = governor.nonce(voter1);
        uint256 deadline = governor.proposalDeadline(proposalId);

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, keccak256(abi.encode(voteTypeHash, voter1, proposalId, FOR, voterNonce + 1, deadline)))
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(voter1PK, digest);

        vm.expectRevert(abi.encodeWithSignature("INVALID_SIGNATURE()"));
        governor.castVoteBySig(voter1, proposalId, FOR, deadline, v, r, s);
    }

    function testRevert_InvalidVoteExpired() public {
        deployMock();

        mintVoter1();

        bytes32 proposalId = createProposal();

        uint256 votingDelay = governor.votingDelay();
        vm.warp(block.timestamp + votingDelay + 1);

        bytes32 domainSeparator = governor.DOMAIN_SEPARATOR();
        bytes32 voteTypeHash = governor.VOTE_TYPEHASH();
        uint256 voterNonce = governor.nonce(voter1);
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, keccak256(abi.encode(voteTypeHash, voter1, proposalId, FOR, voterNonce, deadline)))
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(voter1PK, digest);

        vm.warp(deadline + 1 seconds);

        vm.expectRevert(abi.encodeWithSignature("EXPIRED_SIGNATURE()"));
        governor.castVoteBySig(voter1, proposalId, FOR, deadline, v, r, s);
    }

    function test_QueueProposal() public {
        deployMock();

        mintVoter1();

        bytes32 proposalId = createProposal();

        vm.warp(block.timestamp + governor.votingDelay());

        assertEq(uint256(governor.state(proposalId)), uint256(ProposalState.Active));

        vm.prank(voter1);
        governor.castVote(proposalId, FOR);

        vm.warp(block.timestamp + governor.votingPeriod());

        ProposalState beforeState = governor.state(proposalId);

        vm.prank(voter1);
        governor.queue(proposalId);

        ProposalState afterState = governor.state(proposalId);

        require(beforeState == ProposalState.Succeeded);
        require(afterState == ProposalState.Queued);

        assertEq(treasury.timestamp(proposalId), block.timestamp + treasury.delay());
    }

    function testRevert_CannotQueueVotingStillActive() public {
        deployMock();

        mintVoter1();

        bytes32 proposalId = createProposal();

        uint256 votingDelay = governor.votingDelay();
        vm.warp(block.timestamp + votingDelay);

        vm.prank(voter1);
        governor.castVote(proposalId, FOR);

        uint256 votingPeriod = governor.votingPeriod();
        vm.warp(block.timestamp + votingPeriod - 1);

        assertEq(uint256(governor.state(proposalId)), uint256(ProposalState.Active));

        vm.prank(voter1);
        vm.expectRevert(abi.encodeWithSignature("PROPOSAL_UNSUCCESSFUL()"));
        governor.queue(proposalId);
    }

    /// @notice If a user tries to queue a proposal with a missing hash, revert.
    function testRevert_CannotQueueMissingProposal() public {
        deployMock();

        mintVoter1();

        bytes32 proposalId = createProposal();

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = mockProposal();
        // change the proposer to generate a wrong ID, everything else is the same
        bytes32 wrongProposalId = governor.hashProposal(targets, values, calldatas, "", voter2);

        uint256 votingDelay = governor.votingDelay();
        vm.warp(block.timestamp + votingDelay);

        vm.prank(voter1);
        governor.castVote(proposalId, FOR);

        uint256 votingPeriod = governor.votingPeriod();
        vm.warp(block.timestamp + votingPeriod + 1);

        vm.prank(voter1);
        vm.expectRevert(abi.encodeWithSignature("PROPOSAL_DOES_NOT_EXIST()"));
        governor.queue(wrongProposalId);
    }

    function testRevert_CannotQueueDraw() public {
        deployMock();

        mintVoter1();
        mintVoter2();

        bytes32 proposalId = createProposal();

        uint256 votingDelay = governor.votingDelay();
        vm.warp(block.timestamp + votingDelay);

        vm.prank(voter1);
        governor.castVote(proposalId, AGAINST);
        vm.prank(voter2);
        governor.castVote(proposalId, FOR);

        uint256 votingPeriod = governor.votingPeriod();
        vm.warp(block.timestamp + votingPeriod);

        assertEq(uint256(governor.state(proposalId)), uint256(ProposalState.Defeated));

        vm.prank(voter1);
        vm.expectRevert(abi.encodeWithSignature("PROPOSAL_UNSUCCESSFUL()"));
        governor.queue(proposalId);
    }

    function testRevert_CannotQueueFailed() public {
        deployMock();

        mintVoter1();

        bytes32 proposalId = createProposal();

        uint256 votingDelay = governor.votingDelay();
        vm.warp(block.timestamp + votingDelay);

        vm.prank(voter1);
        governor.castVote(proposalId, AGAINST);

        uint256 votingPeriod = governor.votingPeriod();
        vm.warp(block.timestamp + votingPeriod);

        assertEq(uint256(governor.state(proposalId)), uint256(ProposalState.Defeated));

        vm.prank(voter1);
        vm.expectRevert(abi.encodeWithSignature("PROPOSAL_UNSUCCESSFUL()"));
        governor.queue(proposalId);
    }

    function testRevert_CannotQueueFailedQuorum() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        createVoters(10, 5 ether);

        vm.prank(address(treasury));
        governor.updateQuorumThresholdBps(2000);

        bytes32 proposalId = createProposal();

        vm.warp(block.timestamp + governor.votingDelay());

        castVotes(proposalId, 0, 1, 3); // AGAINST: 0, FOR: 1, ABSTAIN: 3

        vm.warp(block.timestamp + governor.votingPeriod());

        vm.expectRevert(abi.encodeWithSignature("PROPOSAL_UNSUCCESSFUL()"));
        governor.queue(proposalId);
    }

    function test_CancelProposal() public {
        deployMock();

        bytes32 proposalId = createProposal();

        vm.prank(voter1);
        governor.cancel(proposalId);

        Proposal memory proposal = governor.getProposal(proposalId);

        assertTrue(proposal.canceled);
    }

    function test_CancelProposalAndTreasuryQueue() public {
        deployMock();

        mintVoter1();
        bytes32 proposalId = createProposal();

        vm.warp(block.timestamp + governor.votingDelay());

        vm.prank(voter1);
        governor.castVote(proposalId, FOR);

        vm.warp(block.timestamp + governor.votingPeriod());

        governor.queue(proposalId);

        vm.prank(voter1);
        governor.cancel(proposalId);

        Proposal memory proposal = governor.getProposal(proposalId);

        assertTrue(proposal.canceled);
    }

    function test_CancelProposerFellBelowThreshold() public {
        deployAltMock();

        mintVoter1();

        vm.warp(block.timestamp + 1 days);

        for (uint256 i; i < 96; i++) {
            vm.prank(address(auction));
            token.mint();
        }

        assertEq(token.totalSupply(), 100);

        bytes32 proposalId = createProposal();

        vm.warp(block.timestamp + governor.votingDelay());

        vm.startPrank(voter1);
        token.transferFrom(voter1, address(this), 2);

        vm.warp(block.timestamp + governor.votingPeriod());

        governor.cancel(proposalId);

        Proposal memory proposal = governor.getProposal(proposalId);

        assertTrue(proposal.canceled);
        vm.stopPrank();
    }

    function testRevert_CannotCancelIfExactThreshold() public {
        deployAltMock();

        mintVoter1();

        vm.warp(block.timestamp + 1 days);

        for (uint256 i; i < 96; i++) {
            vm.prank(address(auction));
            token.mint();
        }

        assertEq(token.totalSupply(), 100);

        bytes32 proposalId = createProposal();

        vm.warp(block.timestamp + governor.votingDelay() + governor.votingPeriod());

        vm.expectRevert(abi.encodeWithSignature("INVALID_CANCEL()"));
        governor.cancel(proposalId);
    }

    function testRevert_CannotCancelAlreadyExecuted() public {
        deployMock();

        mintVoter1();

        bytes32 proposalId = createProposal();

        vm.warp(block.timestamp + governor.votingDelay());

        vm.prank(voter1);
        governor.castVote(proposalId, FOR);

        vm.warp(block.timestamp + governor.votingPeriod());

        governor.queue(proposalId);

        vm.warp(block.timestamp + treasury.delay());

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = mockProposal();

        governor.execute(targets, values, calldatas, keccak256(bytes("")), voter1);

        vm.expectRevert(abi.encodeWithSignature("PROPOSAL_ALREADY_EXECUTED()"));
        governor.cancel(proposalId);
    }

    function testRevert_ProposerAboveThreshold() public {
        deployMock();

        mintVoter1();

        vm.prank(address(treasury));
        governor.updateProposalThresholdBps(999);

        bytes32 proposalId = createProposal();

        vm.warp(block.timestamp + governor.votingDelay());

        vm.expectRevert(abi.encodeWithSignature("INVALID_CANCEL()"));
        governor.cancel(proposalId);
    }

    function test_VetoProposal() public {
        deployMock();

        bytes32 proposalId = createProposal();

        vm.prank(founder);
        governor.veto(proposalId);

        assertEq(uint8(governor.state(proposalId)), uint8(ProposalState.Vetoed));
    }

    function testRevert_CallerNotVetoer() public {
        deployMock();

        bytes32 proposalId = createProposal();

        vm.expectRevert(abi.encodeWithSignature("ONLY_VETOER()"));
        governor.veto(proposalId);
    }

    function testRevert_CannotVetoExecuted() public {
        deployMock();

        mintVoter1();

        bytes32 proposalId = createProposal();

        vm.warp(block.timestamp + governor.votingDelay());

        vm.prank(voter1);
        governor.castVote(proposalId, FOR);

        vm.warp(block.timestamp + governor.votingPeriod());

        governor.queue(proposalId);

        vm.warp(block.timestamp + treasury.delay());

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = mockProposal();

        governor.execute(targets, values, calldatas, keccak256(bytes("")), voter1);

        vm.expectRevert(abi.encodeWithSignature("PROPOSAL_ALREADY_EXECUTED()"));
        vm.prank(founder);
        governor.veto(proposalId);
    }

    function test_ProposalVoteQueueExecution() public {
        deployMock();

        mintVoter1();

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = mockProposal();

        bytes32 descriptionHash = keccak256(bytes("test"));

        vm.warp(block.timestamp + 1 days);

        vm.prank(voter1);
        governor.propose(targets, values, calldatas, "test");

        bytes32 proposalId = governor.hashProposal(targets, values, calldatas, descriptionHash, voter1);

        vm.warp(block.timestamp + governor.votingDelay());
        vm.prank(voter1);
        governor.castVote(proposalId, 1);

        vm.warp(block.timestamp + governor.votingPeriod());
        vm.prank(voter1);
        governor.queue(proposalId);

        vm.warp(block.timestamp + 2 days);

        governor.execute(targets, values, calldatas, descriptionHash, voter1);

        assertEq(auction.paused(), true);
    }

    function test_UpdateDelay(uint128 _newDelay) public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        createVoters(10, 5 ether);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(treasury);
        calldatas[0] = abi.encodeWithSignature("updateDelay(uint256)", _newDelay);

        vm.prank(otherUsers[2]);
        bytes32 proposalId = governor.propose(targets, values, calldatas, "");

        vm.warp(block.timestamp + governor.votingDelay());

        castVotes(proposalId, 2, 5, 3); // AGAINST: 2, FOR: 5, ABSTAIN: 3

        vm.warp(block.timestamp + governor.votingPeriod());

        assertEq(uint8(governor.state(proposalId)), uint8(ProposalState.Succeeded));

        governor.queue(proposalId);

        vm.warp(block.timestamp + treasury.delay());

        assertEq(treasury.delay(), 2 days);

        governor.execute(targets, values, calldatas, keccak256(bytes("")), otherUsers[2]);

        assertEq(treasury.delay(), _newDelay);
    }

    function test_DelegateAndTransferVotes() public {
        deployMock();

        mintVoter1();

        // uint256 voter2PK = 0xABD;
        // address voter2 = vm.addr(voter2PK);

        assertEq(token.getVotes(voter1), 1);
        assertEq(token.getVotes(voter2), 0);

        vm.prank(voter1);
        token.delegate(voter2);

        assertEq(token.getVotes(voter1), 0);
        assertEq(token.getVotes(voter2), 1);

        vm.prank(voter1);
        token.transferFrom(voter1, voter2, 2);

        assertEq(token.getVotes(voter1), 0);
        assertEq(token.getVotes(voter2), 1);

        vm.prank(voter2);
        token.delegate(voter2);

        assertEq(token.getVotes(voter1), 0);
        assertEq(token.getVotes(voter2), 1);
    }

    function test_GracePeriod(uint128 _newGracePeriod) public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        createVoters(10, 5 ether);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(treasury);
        calldatas[0] = abi.encodeWithSignature("updateGracePeriod(uint256)", _newGracePeriod);

        vm.prank(otherUsers[2]);
        bytes32 proposalId = governor.propose(targets, values, calldatas, "");

        vm.warp(block.timestamp + governor.votingDelay());

        castVotes(proposalId, 2, 5, 3); // AGAINST: 2, FOR: 5, ABSTAIN: 3

        vm.warp(block.timestamp + governor.votingPeriod());

        assertEq(uint8(governor.state(proposalId)), uint8(ProposalState.Succeeded));

        governor.queue(proposalId);

        vm.warp(block.timestamp + treasury.delay());

        assertEq(treasury.gracePeriod(), 2 weeks);

        governor.execute(targets, values, calldatas, keccak256(bytes("")), otherUsers[2]);

        assertEq(treasury.gracePeriod(), _newGracePeriod);
    }

    function test_TreasuryReceive721SafeTransfer(uint256 _tokenId) public {
        deployMock();

        mock721.mint(address(this), _tokenId);

        mock721.safeTransferFrom(address(this), address(treasury), _tokenId);

        assertEq(mock721.ownerOf(_tokenId), address(treasury));
    }

    function test_TreasuryReceiveERC1155SingleTransfer(uint256 _tokenId, uint256 _amount) public {
        deployMock();

        mock1155.mint(address(treasury), _tokenId, _amount);

        assertEq(mock1155.balanceOf(address(treasury), _tokenId), _amount);
    }

    function test_TreasuryReceiveERC1155BatchTransfer() public {
        deployMock();

        address[] memory accounts = new address[](3);
        uint256[] memory tokenIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);

        accounts[0] = address(treasury);
        accounts[1] = address(treasury);
        accounts[2] = address(treasury);

        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;

        amounts[0] = 1 ether;
        amounts[1] = 5 ether;
        amounts[2] = 10 ether;

        mock1155.mintBatch(address(treasury), tokenIds, amounts);

        assertEq(mock1155.balanceOfBatch(accounts, tokenIds), amounts);
    }

    function testFail_GovernorCannotReceive721SafeTransfer() public {
        deployMock();

        mock721.mint(address(this), 1);

        mock721.safeTransferFrom(address(this), address(governor), 1);
    }

    function testFail_GovernorCannotReceive1155SingleTransfer(uint256 _tokenId, uint256 _amount) public {
        deployMock();

        mock1155.mint(address(governor), _tokenId, _amount);
    }

    function testFail_GovernorCannotReceive1155BatchTransfer(uint256[] memory _tokenIds, uint256[] memory _amounts) public {
        deployMock();

        mock1155.mintBatch(address(governor), _tokenIds, _amounts);
    }
}
