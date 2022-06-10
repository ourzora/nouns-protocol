// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {GovernorUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IUpgradeManager} from "../../upgrades/IUpgradeManager.sol";
import {GovernorStorageV1, ITreasury, IToken} from "./storage/GovernorStorageV1.sol";

/// @notice PLACEHOLDER FOR OpenZeppelin's `GovernorUpgradeable`
/// @notice Modified version of NounsDAOLogicV1.sol (commit 2cbe6c7) that NounsDAO licensed under the GPL-3.0 license
contract Governor is GovernorStorageV1, UUPSUpgradeable, OwnableUpgradeable {
    ///                                                          ///
    ///                           CONSTANTS                      ///
    ///                                                          ///

    /// @notice The name of this contract
    string public constant name = "Token DAO Governor";

    /// @notice The minimum setable proposal threshold
    uint256 public constant MIN_PROPOSAL_THRESHOLD_BPS = 1;

    /// @notice The maximum setable proposal threshold
    uint256 public constant MAX_PROPOSAL_THRESHOLD_BPS = 1_000;

    /// @notice The minimum setable voting period
    uint256 public constant MIN_VOTING_PERIOD = 24 hours;

    /// @notice The max setable voting period
    uint256 public constant MAX_VOTING_PERIOD = 2 weeks;

    /// @notice The min setable voting delay
    uint256 public constant MIN_VOTING_DELAY = 1;

    /// @notice The max setable voting delay
    uint256 public constant MAX_VOTING_DELAY = 1 weeks;

    /// @notice The minimum setable quorum votes basis points
    uint256 public constant MIN_QUORUM_VOTES_BPS = 200;

    /// @notice The maximum setable quorum votes basis points
    uint256 public constant MAX_QUORUM_VOTES_BPS = 2_000;

    /// @notice The maximum number of actions that can be included in a proposal
    uint256 public constant proposalMaxOperations = 10;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the ballot struct used by the contract
    bytes32 public constant BALLOT_TYPEHASH = keccak256("Ballot(uint256 proposalId,uint8 support)");

    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    IUpgradeManager private immutable UpgradeManager;

    constructor(address _upgradeManager) payable initializer {
        UpgradeManager = IUpgradeManager(_upgradeManager);
    }

    ///                                                          ///
    ///                          INITIALIZER                     ///
    ///                                                          ///

    function initialize(
        address _treasury,
        address _token,
        address _vetoer,
        uint256 _votingPeriod,
        uint256 _votingDelay,
        uint256 _proposalThresholdBPS,
        uint256 _quorumVotesBPS
    ) public initializer {
        require(msg.sender == admin, "ONLY_ADMIN");
        require(_treasury != address(0), "INVALID_TREASURY");
        require(_token != address(0), "INVALID_TOKEN");
        require(_votingPeriod >= MIN_VOTING_PERIOD && _votingPeriod <= MAX_VOTING_PERIOD, "INVALID_VOTING_PERIOD");
        require(_votingDelay >= MIN_VOTING_DELAY && _votingDelay <= MAX_VOTING_DELAY, "INVALID_VOTING_DELAY");
        require(
            _proposalThresholdBPS >= MIN_PROPOSAL_THRESHOLD_BPS && _proposalThresholdBPS <= MAX_PROPOSAL_THRESHOLD_BPS,
            "INVALID_PROPOSAL_THRESHOLD"
        );
        require(_quorumVotesBPS >= MIN_QUORUM_VOTES_BPS && _quorumVotesBPS <= MAX_QUORUM_VOTES_BPS, "INVALID_QUORUM_THRESHOLD");

        __UUPSUpgradeable_init();

        __Ownable_init();

        transferOwnership(_treasury);

        treasury = ITreasury(_treasury);
        token = IToken(_token);
        vetoer = _vetoer;
        votingPeriod = _votingPeriod;
        votingDelay = _votingDelay;
        proposalThresholdBPS = _proposalThresholdBPS;
        quorumVotesBPS = _quorumVotesBPS;
    }

    ///                                                          ///
    ///                             PROPOSE                      ///
    ///                                                          ///

    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) public returns (uint256) {
        ProposalTemp memory temp;

        temp.totalSupply = token.totalCount();

        temp.proposalThreshold = bps2Uint(proposalThresholdBPS, temp.totalSupply);

        require(token.getPastVotes(msg.sender, block.number - 1) > temp.proposalThreshold, "PROPOSER_VOTES_BELOW_THRESHOLD");
        require(
            targets.length == values.length && targets.length == signatures.length && targets.length == calldatas.length,
            "PROPOSAL_DATA_MISMATCH"
        );
        require(targets.length != 0, "MUST_PROVIDE_ACTIONS");
        require(targets.length <= proposalMaxOperations, "TOO_MANY_ACTIONS");

        temp.latestProposalId = latestProposalIds[msg.sender];

        if (temp.latestProposalId != 0) {
            ProposalState proposersLatestProposalState = state(temp.latestProposalId);

            require(proposersLatestProposalState != ProposalState.Active, "ACTIVE_PROPOSAL_FOUND");
            require(proposersLatestProposalState != ProposalState.Pending, "PENDING_PROPOSAL_FOUND");
        }

        temp.startBlock = block.number + votingDelay;
        temp.endBlock = temp.startBlock + votingPeriod;

        proposalCount++;
        Proposal storage newProposal = proposals[proposalCount];

        newProposal.id = proposalCount;
        newProposal.proposer = msg.sender;
        newProposal.proposalThreshold = temp.proposalThreshold;
        newProposal.quorumVotes = bps2Uint(quorumVotesBPS, temp.totalSupply);
        newProposal.eta = 0;
        newProposal.targets = targets;
        newProposal.values = values;
        newProposal.signatures = signatures;
        newProposal.calldatas = calldatas;
        newProposal.startBlock = temp.startBlock;
        newProposal.endBlock = temp.endBlock;
        newProposal.forVotes = 0;
        newProposal.againstVotes = 0;
        newProposal.abstainVotes = 0;
        newProposal.canceled = false;
        newProposal.executed = false;
        newProposal.vetoed = false;

        latestProposalIds[newProposal.proposer] = newProposal.id;

        emit ProposalCreated(
            newProposal.id,
            msg.sender,
            targets,
            values,
            signatures,
            calldatas,
            newProposal.startBlock,
            newProposal.endBlock,
            description
        );

        emit ProposalCreatedWithRequirements(
            newProposal.id,
            msg.sender,
            targets,
            values,
            signatures,
            calldatas,
            newProposal.startBlock,
            newProposal.endBlock,
            newProposal.proposalThreshold,
            newProposal.quorumVotes,
            description
        );

        return newProposal.id;
    }

    ///                                                          ///
    ///                              QUEUE                       ///
    ///                                                          ///

    function queue(uint256 proposalId) external {
        require(state(proposalId) == ProposalState.Succeeded, "PROPOSAL_NOT_SUCCESSFUL");

        Proposal storage proposal = proposals[proposalId];

        uint256 eta = block.timestamp + treasury.delay();

        for (uint256 i = 0; i < proposal.targets.length; i++) {
            queueOrRevertInternal(proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], eta);
        }

        proposal.eta = eta;

        emit ProposalQueued(proposalId, eta);
    }

    function queueOrRevertInternal(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) internal {
        require(!treasury.queuedTransactions(keccak256(abi.encode(target, value, signature, data, eta))), "IDENTICAL_PROPOSAL_QUEUED");
        treasury.queueTransaction(target, value, signature, data, eta);
    }

    ///                                                          ///
    ///                             EXECUTE                      ///
    ///                                                          ///

    function execute(uint256 proposalId) external {
        require(state(proposalId) == ProposalState.Queued, "PROPOSAL_MUST_BE_QUEUED");
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            treasury.executeTransaction(proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], proposal.eta);
        }
        emit ProposalExecuted(proposalId);
    }

    ///                                                          ///
    ///                             CANCEL                       ///
    ///                                                          ///

    function cancel(uint256 proposalId) external {
        require(state(proposalId) != ProposalState.Executed, "PROPOSAL_ALREADY_EXECUTED");

        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == proposal.proposer || token.getPastVotes(proposal.proposer, block.number - 1) < proposal.proposalThreshold,
            "PROPOSER_ABOVE_THRESHOLD"
        );

        proposal.canceled = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            treasury.cancelTransaction(proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], proposal.eta);
        }

        emit ProposalCanceled(proposalId);
    }

    ///                                                          ///
    ///                            CAST VOTE                     ///
    ///                                                          ///

    function castVote(uint256 proposalId, uint8 support) external {
        emit VoteCast(msg.sender, proposalId, support, castVoteInternal(msg.sender, proposalId, support), "");
    }

    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external {
        emit VoteCast(msg.sender, proposalId, support, castVoteInternal(msg.sender, proposalId, support), reason);
    }

    function castVoteBySig(
        uint256 proposalId,
        uint8 support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        bytes32 domainSeparator = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), getChainIdInternal(), address(this)));
        bytes32 structHash = keccak256(abi.encode(BALLOT_TYPEHASH, proposalId, support));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);

        require(signatory != address(0), "INVALID_SIG");

        emit VoteCast(signatory, proposalId, support, castVoteInternal(signatory, proposalId, support), "");
    }

    function castVoteInternal(
        address voter,
        uint256 proposalId,
        uint8 support
    ) internal returns (uint96) {
        require(state(proposalId) == ProposalState.Active, "VOTING_CLOSED");
        require(support <= 2, "INVALID_VOTE_TYPE");
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        require(receipt.hasVoted == false, "ALREADY_VOTED");

        uint96 votes = uint96(token.getPastVotes(voter, proposal.startBlock - votingDelay));

        if (support == 0) {
            proposal.againstVotes = proposal.againstVotes + votes;
        } else if (support == 1) {
            proposal.forVotes = proposal.forVotes + votes;
        } else if (support == 2) {
            proposal.abstainVotes = proposal.abstainVotes + votes;
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        return votes;
    }

    ///                                                          ///
    ///                           VIEW STATE                     ///
    ///                                                          ///

    function getActions(uint256 proposalId)
        external
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        )
    {
        Proposal storage p = proposals[proposalId];
        return (p.targets, p.values, p.signatures, p.calldatas);
    }

    function getReceipt(uint256 proposalId, address voter) external view returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
    }

    function state(uint256 proposalId) public view returns (ProposalState) {
        require(proposalCount >= proposalId, "INVALID_PROPOSAL_ID");

        Proposal storage proposal = proposals[proposalId];

        if (proposal.vetoed) {
            return ProposalState.Vetoed;
        } else if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < proposal.quorumVotes) {
            return ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= proposal.eta + treasury.GRACE_PERIOD()) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    function proposalThreshold() public view returns (uint256) {
        return bps2Uint(proposalThresholdBPS, token.totalCount());
    }

    function quorumVotes() public view returns (uint256) {
        return bps2Uint(quorumVotesBPS, token.totalCount());
    }

    ///                                                          ///
    ///                              VETO                        ///
    ///                                                          ///

    function veto(uint256 proposalId) external {
        require(vetoer != address(0), "VETOER_BURNED");
        require(msg.sender == vetoer, "ONLY_VETOER");
        require(state(proposalId) != ProposalState.Executed, "PROPOSAL_EXCUTED");

        Proposal storage proposal = proposals[proposalId];

        proposal.vetoed = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            treasury.cancelTransaction(proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], proposal.eta);
        }

        emit ProposalVetoed(proposalId);
    }

    ///                                                          ///
    ///                             ADMIN                        ///
    ///                                                          ///

    function _setVotingDelay(uint256 newVotingDelay) external {
        require(msg.sender == admin, "ONLY_ADMIN");
        require(newVotingDelay >= MIN_VOTING_DELAY && newVotingDelay <= MAX_VOTING_DELAY, "INVALID_VOTING_DELAY");
        uint256 oldVotingDelay = votingDelay;
        votingDelay = newVotingDelay;

        emit VotingDelaySet(oldVotingDelay, votingDelay);
    }

    function _setVotingPeriod(uint256 newVotingPeriod) external {
        require(msg.sender == admin, "ONLY_ADMIN");
        require(newVotingPeriod >= MIN_VOTING_PERIOD && newVotingPeriod <= MAX_VOTING_PERIOD, "INVALID_VOTING_PERIOD");
        uint256 oldVotingPeriod = votingPeriod;
        votingPeriod = newVotingPeriod;

        emit VotingPeriodSet(oldVotingPeriod, votingPeriod);
    }

    function _setProposalThresholdBPS(uint256 newProposalThresholdBPS) external {
        require(msg.sender == admin, "ONLY_ADMIN");
        require(
            newProposalThresholdBPS >= MIN_PROPOSAL_THRESHOLD_BPS && newProposalThresholdBPS <= MAX_PROPOSAL_THRESHOLD_BPS,
            "INVALID_PROPOSAL_THRESHOLD"
        );
        uint256 oldProposalThresholdBPS = proposalThresholdBPS;
        proposalThresholdBPS = newProposalThresholdBPS;

        emit ProposalThresholdBPSSet(oldProposalThresholdBPS, proposalThresholdBPS);
    }

    function _setQuorumVotesBPS(uint256 newQuorumVotesBPS) external {
        require(msg.sender == admin, "ONLY_ADMIN");
        require(newQuorumVotesBPS >= MIN_QUORUM_VOTES_BPS && newQuorumVotesBPS <= MAX_QUORUM_VOTES_BPS, "INVALID_PROPOSAL_THRESHOLD");

        uint256 oldQuorumVotesBPS = quorumVotesBPS;

        quorumVotesBPS = newQuorumVotesBPS;

        emit QuorumVotesBPSSet(oldQuorumVotesBPS, quorumVotesBPS);
    }

    function _setPendingAdmin(address newPendingAdmin) external {
        require(msg.sender == admin, "ONLY_ADMIN");

        address oldPendingAdmin = pendingAdmin;

        pendingAdmin = newPendingAdmin;

        emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin);
    }

    function _acceptAdmin() external {
        require(msg.sender == pendingAdmin && msg.sender != address(0), "ONLY_PENDING_ADMIN");

        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;

        admin = pendingAdmin;

        pendingAdmin = address(0);

        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);
    }

    ///                                                          ///
    ///                              VETO                        ///
    ///                                                          ///

    function _setVetoer(address newVetoer) public {
        require(msg.sender == vetoer, "ONLY_VETOER");

        emit NewVetoer(vetoer, newVetoer);

        vetoer = newVetoer;
    }

    function _burnVetoPower() public {
        require(msg.sender == vetoer, "ONLY_VETOER");

        _setVetoer(address(0));
    }

    ///                                                          ///
    ///                             UTILS                        ///
    ///                                                          ///

    function bps2Uint(uint256 bps, uint256 number) internal pure returns (uint256) {
        return (number * bps) / 10000;
    }

    function getChainIdInternal() internal view returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }

    ///                                                          ///
    ///                         PROXY UPGRADE                    ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract to a valid implementation
    /// @dev This function is called in UUPS `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The address of the new implementation
    function _authorizeUpgrade(address _newImpl) internal override onlyOwner {
        // Ensure the implementation is valid
        require(UpgradeManager.isValidUpgrade(_getImplementation(), _newImpl), "INVALID_UPGRADE");
    }
}
