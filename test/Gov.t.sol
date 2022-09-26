// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

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

    IManager.GovParams internal altGovParams;

    function setUp() public virtual override {
        super.setUp();

        deployMock();

        createVoter1();
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

        setAuctionParams(0, 1 days);

        setGovParams(2 days, 1 days, 1 weeks, 25, 1000);

        deploy(foundersArr, tokenParams, auctionParams, govParams);
    }

    function createVoter1() internal {
        voter1PK = 0xABE;
        voter1 = vm.addr(voter1PK);

        vm.deal(voter1, 100 ether);
    }

    function mintVoter1() internal {
        vm.prank(founder);
        auction.unpause();

        vm.prank(voter1);
        auction.createBid{ value: 0.420 ether }(2);

        vm.warp(auctionParams.duration + 1 seconds);
        auction.settleCurrentAndCreateNewAuction();
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

        vm.prank(voter1);
        proposalId = governor.propose(targets, values, calldatas, "");
    }

    function createProposal(
        address _proposer,
        address _target,
        uint256 _value,
        bytes memory _calldata
    ) internal returns (bytes32 proposalId) {
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
        assertEq(treasury.owner(), address(governor));
        assertEq(treasury.delay(), govParams.timelockDelay);
    }

    function testRevert_CannotReinitializeGovernor() public {
        vm.expectRevert(abi.encodeWithSignature("ALREADY_INITIALIZED()"));
        governor.initialize(address(this), address(this), address(this), 0, 0, 0, 0);
    }

    function testRevert_CannotReinitializeTreasury() public {
        vm.expectRevert(abi.encodeWithSignature("ALREADY_INITIALIZED()"));
        treasury.initialize(address(this), 0);
    }

    function test_CreateProposal() public {
        mintVoter1();

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = mockProposal();

        bytes32 descriptionHash = keccak256(bytes(""));
        bytes32 proposalId = governor.hashProposal(targets, values, calldatas, descriptionHash);

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

        assertEq(treasury.hashProposal(targets, values, calldatas, descriptionHash), proposalId);
    }

    function testRevert_NoTarget() public {
        mintVoter1();

        address[] memory targets;
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        calldatas[0] = abi.encodeWithSignature("pause()");

        vm.expectRevert(abi.encodeWithSignature("PROPOSAL_TARGET_MISSING()"));
        governor.propose(targets, values, calldatas, "");
    }

    function testRevert_NoValue() public {
        mintVoter1();

        address[] memory targets = new address[](1);
        uint256[] memory values;
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(auction);
        calldatas[0] = abi.encodeWithSignature("pause()");

        vm.expectRevert(abi.encodeWithSignature("PROPOSAL_LENGTH_MISMATCH()"));
        governor.propose(targets, values, calldatas, "");
    }

    function testRevert_NoCalldata() public {
        mintVoter1();

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas;

        targets[0] = address(auction);

        vm.expectRevert(abi.encodeWithSignature("PROPOSAL_LENGTH_MISMATCH()"));
        governor.propose(targets, values, calldatas, "");
    }

    function testRevert_ProposalExists() public {
        mintVoter1();

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(auction);
        calldatas[0] = abi.encodeWithSignature("pause()");

        bytes32 descriptionHash = keccak256(bytes(""));

        bytes32 proposalId = governor.hashProposal(targets, values, calldatas, descriptionHash);

        governor.propose(targets, values, calldatas, "");

        vm.expectRevert(abi.encodeWithSignature("PROPOSAL_EXISTS(bytes32)", proposalId));
        governor.propose(targets, values, calldatas, "");
    }

    function testRevert_BelowProposalThreshold() public {
        mintVoter1();

        vm.prank(address(treasury));
        governor.updateProposalThresholdBps(5000);

        assertEq(governor.proposalThreshold(), 2);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(auction);
        calldatas[0] = abi.encodeWithSignature("");

        vm.expectRevert(abi.encodeWithSignature("BELOW_PROPOSAL_THRESHOLD()"));
        governor.propose(targets, values, calldatas, "");
    }

    function test_CastVote() public {
        mintVoter1();

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

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(voter1PK, digest);

        governor.castVoteBySig(voter1, proposalId, FOR, deadline, v, r, s);

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);

        assertEq(againstVotes, 0);
        assertEq(forVotes, 1);
        assertEq(abstainVotes, 0);
    }

    function testRevert_VotingNotStarted() public {
        mintVoter1();

        bytes32 proposalId = createProposal();

        vm.expectRevert(abi.encodeWithSignature("VOTING_NOT_STARTED()"));
        vm.prank(voter1);
        governor.castVote(proposalId, FOR);
    }

    function testRevert_CannotVoteTwice() public {
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
        mintVoter1();

        bytes32 proposalId = createProposal();

        uint256 votingDelay = governor.votingDelay();
        vm.warp(block.timestamp + votingDelay + 1);

        vm.expectRevert(abi.encodeWithSignature("INVALID_VOTE()"));
        governor.castVote(proposalId, 3);
    }

    function testRevert_InvalidVoteSigner() public {
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

    function testRevert_CannotQueueFailed() public {
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
        bytes32 proposalId = createProposal();

        vm.prank(voter1);
        governor.cancel(proposalId);

        Proposal memory proposal = governor.getProposal(proposalId);

        assertTrue(proposal.canceled);
    }

    function test_CancelProposalAndTreasuryQueue() public {
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
        mintVoter1();

        vm.prank(address(treasury));
        governor.updateProposalThresholdBps(1000);

        bytes32 proposalId = createProposal();

        vm.warp(block.timestamp + governor.votingDelay());

        vm.prank(voter1);
        token.transferFrom(voter1, address(this), 2);

        vm.warp(block.timestamp + governor.votingPeriod());

        governor.cancel(proposalId);

        Proposal memory proposal = governor.getProposal(proposalId);

        assertTrue(proposal.canceled);
    }

    function testRevert_CannotCancelAlreadyExecuted() public {
        mintVoter1();

        bytes32 proposalId = createProposal();

        vm.warp(block.timestamp + governor.votingDelay());

        vm.prank(voter1);
        governor.castVote(proposalId, FOR);

        vm.warp(block.timestamp + governor.votingPeriod());

        governor.queue(proposalId);

        vm.warp(block.timestamp + treasury.delay());

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = mockProposal();

        governor.execute(targets, values, calldatas, keccak256(bytes("")));

        vm.expectRevert(abi.encodeWithSignature("PROPOSAL_ALREADY_EXECUTED()"));
        governor.cancel(proposalId);
    }

    function testRevert_ProposerAboveThreshold() public {
        mintVoter1();

        vm.prank(address(treasury));
        governor.updateProposalThresholdBps(1000);

        bytes32 proposalId = createProposal();

        vm.warp(block.timestamp + governor.votingDelay());

        vm.expectRevert(abi.encodeWithSignature("INVALID_CANCEL()"));
        governor.cancel(proposalId);
    }

    function test_VetoProposal() public {
        bytes32 proposalId = createProposal();

        vm.prank(founder);
        governor.veto(proposalId);

        assertEq(uint8(governor.state(proposalId)), uint8(ProposalState.Vetoed));
    }

    function testRevert_CallerNotVetoer() public {
        bytes32 proposalId = createProposal();

        vm.expectRevert(abi.encodeWithSignature("ONLY_VETOER()"));
        governor.veto(proposalId);
    }

    function testRevert_CannotVetoExecuted() public {
        mintVoter1();

        bytes32 proposalId = createProposal();

        vm.warp(block.timestamp + governor.votingDelay());

        vm.prank(voter1);
        governor.castVote(proposalId, FOR);

        vm.warp(block.timestamp + governor.votingPeriod());

        governor.queue(proposalId);

        vm.warp(block.timestamp + treasury.delay());

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = mockProposal();

        governor.execute(targets, values, calldatas, keccak256(bytes("")));

        vm.expectRevert(abi.encodeWithSignature("PROPOSAL_ALREADY_EXECUTED()"));
        vm.prank(founder);
        governor.veto(proposalId);
    }

    function test_ProposalVoteQueueExecution() public {
        mintVoter1();

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = mockProposal();

        bytes32 descriptionHash = keccak256(bytes("test"));

        vm.warp(1 days);

        vm.prank(voter1);
        governor.propose(targets, values, calldatas, "test");

        bytes32 proposalId = governor.hashProposal(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + governor.votingDelay());

        vm.prank(voter1);
        governor.castVote(proposalId, 1);

        vm.warp(block.timestamp + governor.votingPeriod());

        vm.prank(voter1);
        governor.queue(proposalId);

        vm.warp(block.timestamp + 2 days);

        governor.execute(targets, values, calldatas, descriptionHash);

        assertEq(auction.paused(), true);
    }

    function test_UpdateDelay(uint128 _newDelay) public {
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

        governor.execute(targets, values, calldatas, keccak256(bytes("")));

        assertEq(treasury.delay(), _newDelay);
    }

    function test_GracePeriod(uint128 _newGracePeriod) public {
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

        governor.execute(targets, values, calldatas, keccak256(bytes("")));

        assertEq(treasury.gracePeriod(), _newGracePeriod);
    }

    function test_TreasuryReceive721SafeTransfer(uint256 _tokenId) public {
        mock721.mint(address(this), _tokenId);

        mock721.safeTransferFrom(address(this), address(treasury), _tokenId);

        assertEq(mock721.ownerOf(_tokenId), address(treasury));
    }

    function test_TreasuryReceiveERC1155SingleTransfer(uint256 _tokenId, uint256 _amount) public {
        mock1155.mint(address(treasury), _tokenId, _amount);

        assertEq(mock1155.balanceOf(address(treasury), _tokenId), _amount);
    }

    function test_TreasuryReceiveERC1155BatchTransfer() public {
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
        mock721.mint(address(this), 1);

        mock721.safeTransferFrom(address(this), address(governor), 1);
    }

    function testFail_GovernorCannotReceive1155SingleTransfer(uint256 _tokenId, uint256 _amount) public {
        mock1155.mint(address(governor), _tokenId, _amount);
    }

    function testFail_GovernorCannotReceive1155BatchTransfer(uint256[] memory _tokenIds, uint256[] memory _amounts) public {
        mock1155.mintBatch(address(governor), _tokenIds, _amounts);
    }
}
