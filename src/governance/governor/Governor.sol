// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { UUPS } from "../../lib/proxy/UUPS.sol";
import { Ownable } from "../../lib/utils/Ownable.sol";
import { EIP712 } from "../../lib/utils/EIP712.sol";
import { SafeCast } from "../../lib/utils/SafeCast.sol";

import { GovernorStorageV1 } from "./storage/GovernorStorageV1.sol";
import { Token } from "../../token/Token.sol";
import { Treasury } from "../treasury/Treasury.sol";
import { IManager } from "../../manager/IManager.sol";
import { IGovernor } from "./IGovernor.sol";

/// @title Governor
/// @author Rohan Kulkarni
/// @notice A DAO's proposal manager and transaction scheduler
/// Modified from:
/// - OpenZeppelin Contracts v4.7.3 (governance/extensions/GovernorTimelockControl.sol)
/// - NounsDAOLogicV1.sol commit 2cbe6c7 - licensed under the BSD-3-Clause license.
contract Governor is IGovernor, UUPS, Ownable, EIP712, GovernorStorageV1 {
    ///                                                          ///
    ///                         CONSTANTS                        ///
    ///                                                          ///

    /// @notice The EIP-712 typehash to vote with a signature
    bytes32 public constant VOTE_TYPEHASH = keccak256("Vote(address voter,uint256 proposalId,uint256 support,uint256 nonce,uint256 deadline)");

    ///                                                          ///
    ///                         IMMUTABLES                       ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IManager private immutable manager;

    ///                                                          ///
    ///                         CONSTRUCTOR                      ///
    ///                                                          ///

    /// @param _manager The contract upgrade manager address
    constructor(address _manager) payable initializer {
        manager = IManager(_manager);
    }

    ///                                                          ///
    ///                         INITIALIZER                      ///
    ///                                                          ///

    /// @notice Initializes a DAO's governor
    /// @param _treasury The DAO's treasury address
    /// @param _token The DAO's governance token address
    /// @param _vetoer The address eligible to veto proposals
    /// @param _votingDelay The voting delay
    /// @param _votingPeriod The voting period
    /// @param _proposalThresholdBps The proposal threshold basis points
    /// @param _quorumThresholdBps The quorum threshold basis points
    function initialize(
        address _treasury,
        address _token,
        address _vetoer,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThresholdBps,
        uint256 _quorumThresholdBps
    ) external initializer {
        // Ensure the caller is the contract manager
        if (msg.sender != address(manager)) revert ONLY_MANAGER();

        // Ensure non-zero addresses are provided
        if (_treasury == address(0)) revert ADDRESS_ZERO();
        if (_token == address(0)) revert ADDRESS_ZERO();

        // Store the governor settings
        settings.treasury = Treasury(payable(_treasury));
        settings.token = Token(_token);
        settings.vetoer = _vetoer;
        settings.votingDelay = SafeCast.toUint48(_votingDelay);
        settings.votingPeriod = SafeCast.toUint48(_votingPeriod);
        settings.proposalThresholdBps = SafeCast.toUint16(_proposalThresholdBps);
        settings.quorumThresholdBps = SafeCast.toUint16(_quorumThresholdBps);

        // Initialize EIP-712 support
        __EIP712_init(string.concat(settings.token.symbol(), " GOV"), "1");

        // Grant ownership to the treasury
        __Ownable_init(_treasury);
    }

    ///                                                          ///
    ///                         HASH PROPOSAL                    ///
    ///                                                          ///

    /// @notice Hashes a proposal's details into a proposal id
    /// @param _targets The target addresses to call
    /// @param _values The ETH values of each call
    /// @param _calldatas The calldata of each call
    /// @param _descriptionHash The hash of the description
    function hashProposal(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(_targets, _values, _calldatas, _descriptionHash));
    }

    ///                                                          ///
    ///                        CREATE PROPOSAL                   ///
    ///                                                          ///

    /// @notice Creates a proposal
    /// @param _targets The target addresses to call
    /// @param _values The ETH values of each call
    /// @param _calldatas The calldata of each call
    /// @param _description The proposal description
    function propose(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description
    ) external returns (bytes32) {
        // Get the current proposal threshold
        uint256 currentProposalThreshold = proposalThreshold();

        // Cannot realistically underflow and `getVotes` would revert
        unchecked {
            // Ensure the caller's voting weight is greater than or equal to the threshold
            if (getVotes(msg.sender, block.timestamp - 1) < proposalThreshold()) revert BELOW_PROPOSAL_THRESHOLD();
        }

        // Cache the number of targets
        uint256 numTargets = _targets.length;

        // Ensure at least one target exists
        if (numTargets == 0) revert PROPOSAL_TARGET_MISSING();

        // Ensure the number of targets matches the number of values and calldata
        if (numTargets != _values.length) revert PROPOSAL_LENGTH_MISMATCH();
        if (numTargets != _calldatas.length) revert PROPOSAL_LENGTH_MISMATCH();

        // Compute the description hash
        bytes32 descriptionHash = keccak256(bytes(_description));

        // Compute the proposal id
        bytes32 proposalId = hashProposal(_targets, _values, _calldatas, descriptionHash);

        // Get the pointer to store the proposal
        Proposal storage proposal = proposals[proposalId];

        // Ensure the proposal doesn't already exist
        if (proposal.voteStart != 0) revert PROPOSAL_EXISTS(proposalId);

        // Used to store the snapshot and deadline
        uint256 snapshot;
        uint256 deadline;

        // Cannot realistically overflow
        unchecked {
            // Compute the snapshot and deadline
            snapshot = block.timestamp + settings.votingDelay;
            deadline = snapshot + settings.votingPeriod;
        }

        // Store the proposal data
        proposal.voteStart = uint32(snapshot);
        proposal.voteEnd = uint32(deadline);
        proposal.proposalThreshold = uint32(currentProposalThreshold);
        proposal.quorumVotes = uint32(quorum());
        proposal.proposer = msg.sender;
        proposal.timeCreated = uint32(block.timestamp);

        emit ProposalCreated(proposalId, _targets, _values, _calldatas, _description, descriptionHash, proposal);

        return proposalId;
    }

    ///                                                          ///
    ///                          CAST VOTE                       ///
    ///                                                          ///

    /// @notice Casts a vote
    /// @param _proposalId The proposal id
    /// @param _support The support value (0 = Against, 1 = For, 2 = Abstain)
    function castVote(bytes32 _proposalId, uint256 _support) external returns (uint256) {
        return _castVote(_proposalId, msg.sender, _support, "");
    }

    /// @notice Casts a vote with a reason
    /// @param _proposalId The proposal id
    /// @param _support The support value (0 = Against, 1 = For, 2 = Abstain)
    /// @param _reason The vote reason
    function castVoteWithReason(
        bytes32 _proposalId,
        uint256 _support,
        string memory _reason
    ) external returns (uint256) {
        return _castVote(_proposalId, msg.sender, _support, _reason);
    }

    /// @notice Casts a signed vote
    /// @param _voter The voter address
    /// @param _proposalId The proposal id
    /// @param _support The support value (0 = Against, 1 = For, 2 = Abstain)
    /// @param _deadline The signature deadline
    /// @param _v The 129th byte and chain id of the signature
    /// @param _r The first 64 bytes of the signature
    /// @param _s Bytes 64-128 of the signature
    function castVoteBySig(
        address _voter,
        bytes32 _proposalId,
        uint256 _support,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external returns (uint256) {
        // Ensure the deadline has not passed
        if (block.timestamp > _deadline) revert EXPIRED_SIGNATURE();

        // Used to store the signed digest
        bytes32 digest;

        // Cannot realistically overflow
        unchecked {
            // Compute the message
            digest = keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(VOTE_TYPEHASH, _voter, _proposalId, _support, nonces[_voter]++, _deadline))
                )
            );
        }

        // Recover the message signer
        address recoveredAddress = ecrecover(digest, _v, _r, _s);

        // Ensure the recovered signer is the given voter
        if (recoveredAddress == address(0) || recoveredAddress != _voter) revert INVALID_SIGNATURE();

        return _castVote(_proposalId, _voter, _support, "");
    }

    /// @dev Stores a vote
    /// @param _proposalId The proposal id
    /// @param _voter The voter address
    /// @param _support The vote choice
    function _castVote(
        bytes32 _proposalId,
        address _voter,
        uint256 _support,
        string memory _reason
    ) internal returns (uint256) {
        // Ensure voting is active
        if (state(_proposalId) != ProposalState.Active) revert VOTING_NOT_STARTED();

        // Ensure the voter hasn't already voted
        if (hasVoted[_proposalId][_voter]) revert ALREADY_VOTED();

        // Ensure the vote is valid
        if (_support > 2) revert INVALID_VOTE();

        // Record the voter as having voted
        hasVoted[_proposalId][_voter] = true;

        // Get the pointer to the proposal
        Proposal storage proposal = proposals[_proposalId];

        // Used to store the voter's weight
        uint256 weight;

        // Cannot realistically underflow and `getVotes` would revert
        unchecked {
            // Get the voter's weight at the time the proposal was created
            weight = getVotes(_voter, proposal.timeCreated);

            // If the vote is against:
            if (_support == 0) {
                // Update the total number of votes against
                proposal.againstVotes += uint32(weight);

                // Else if the vote is for:
            } else if (_support == 1) {
                // Update the total number of votes for
                proposal.forVotes += uint32(weight);

                // Else if the vote is to abstain:
            } else if (_support == 2) {
                // Update the total number of votes abstaining
                proposal.abstainVotes += uint32(weight);
            }
        }

        emit VoteCast(_voter, _proposalId, _support, weight, _reason);

        return weight;
    }

    ///                                                          ///
    ///                        QUEUE PROPOSAL                    ///
    ///                                                          ///

    /// @notice Queues a proposal
    /// @param _proposalId The proposal id
    function queue(bytes32 _proposalId) external returns (uint256 eta) {
        // Ensure the proposal has succeeded
        if (state(_proposalId) != ProposalState.Succeeded) revert PROPOSAL_UNSUCCESSFUL();

        // Schedule the proposal for execution
        eta = settings.treasury.queue(_proposalId);

        emit ProposalQueued(_proposalId, eta);
    }

    ///                                                          ///
    ///                       EXECUTE PROPOSAL                   ///
    ///                                                          ///

    /// @notice Executes a proposal
    /// @param _targets The target addresses to call
    /// @param _values The ETH values of each call
    /// @param _calldatas The calldata of each call
    /// @param _descriptionHash The hash of the description
    function execute(
        address[] calldata _targets,
        uint256[] calldata _values,
        bytes[] calldata _calldatas,
        bytes32 _descriptionHash
    ) external payable returns (bytes32) {
        // Get the proposal id
        bytes32 proposalId = hashProposal(_targets, _values, _calldatas, _descriptionHash);

        // Ensure the proposal is queued
        if (state(proposalId) != ProposalState.Queued) revert PROPOSAL_NOT_QUEUED(proposalId);

        // Mark the proposal as executed
        proposals[proposalId].executed = true;

        // Execute the proposal
        settings.treasury.execute{ value: msg.value }(_targets, _values, _calldatas, _descriptionHash);

        emit ProposalExecuted(proposalId);

        return proposalId;
    }

    ///                                                          ///
    ///                        CANCEL PROPOSAL                   ///
    ///                                                          ///

    /// @notice Cancels a proposal
    /// @param _proposalId The proposal id
    function cancel(bytes32 _proposalId) external {
        // Ensure the proposal hasn't been executed
        if (state(_proposalId) == ProposalState.Executed) revert PROPOSAL_ALREADY_EXECUTED();

        // Get a copy of the proposal
        Proposal memory proposal = proposals[_proposalId];

        // Cannot realistically underflow and `getVotes` would revert
        unchecked {
            // Ensure the caller is the proposer or the proposer's voting weight has dropped below the proposal threshold
            if (msg.sender != proposal.proposer && getVotes(proposal.proposer, block.timestamp - 1) > proposal.proposalThreshold)
                revert INVALID_CANCEL();
        }

        // Update the proposal as canceled
        proposals[_proposalId].canceled = true;

        // If the proposal was queued:
        if (settings.treasury.isQueued(_proposalId)) {
            // Cancel the proposal
            settings.treasury.cancel(_proposalId);
        }

        emit ProposalCanceled(_proposalId);
    }

    ///                                                          ///
    ///                        VETO PROPOSAL                     ///
    ///                                                          ///

    /// @notice Vetoes a proposal
    /// @param _proposalId The proposal id
    function veto(bytes32 _proposalId) external {
        // Ensure the caller is the vetoer
        if (msg.sender != settings.vetoer) revert ONLY_VETOER();

        // Ensure the proposal has not been executed
        if (state(_proposalId) == ProposalState.Executed) revert PROPOSAL_ALREADY_EXECUTED();

        // Get the pointer to the proposal
        Proposal storage proposal = proposals[_proposalId];

        // Update the proposal as vetoed
        proposal.vetoed = true;

        // If the proposal was queued:
        if (settings.treasury.isQueued(_proposalId)) {
            // Cancel the proposal
            settings.treasury.cancel(_proposalId);
        }

        emit ProposalVetoed(_proposalId);
    }

    ///                                                          ///
    ///                        PROPOSAL STATE                    ///
    ///                                                          ///

    /// @notice The state of a proposal
    /// @param _proposalId The proposal id
    function state(bytes32 _proposalId) public view returns (ProposalState) {
        // Get a copy of the proposal
        Proposal memory proposal = proposals[_proposalId];

        // Ensure the proposal exists
        if (proposal.voteStart == 0) revert PROPOSAL_DOES_NOT_EXIST();

        // If the proposal was executed:
        if (proposal.executed) {
            return ProposalState.Executed;

            // Else if the proposal was canceled:
        } else if (proposal.canceled) {
            return ProposalState.Canceled;

            // Else if the proposal was vetoed:
        } else if (proposal.vetoed) {
            return ProposalState.Vetoed;

            // Else if voting has not started:
        } else if (block.timestamp < proposal.voteStart) {
            return ProposalState.Pending;

            // Else if voting has not ended:
        } else if (block.timestamp < proposal.voteEnd) {
            return ProposalState.Active;

            // Else if the proposal failed (outvoted OR didn't reach quorum):
        } else if (proposal.forVotes < proposal.againstVotes || proposal.forVotes < proposal.quorumVotes) {
            return ProposalState.Defeated;

            // Else if the proposal has not been queued:
        } else if (settings.treasury.timestamp(_proposalId) == 0) {
            return ProposalState.Succeeded;

            // Else if the proposal can no longer be executed:
        } else if (settings.treasury.isExpired(_proposalId)) {
            return ProposalState.Expired;

            // Else the proposal is queued
        } else {
            return ProposalState.Queued;
        }
    }

    /// @notice The voting weight of an account at a timestamp
    /// @param _account The account address
    /// @param _timestamp The specific timestamp
    function getVotes(address _account, uint256 _timestamp) public view returns (uint256) {
        return settings.token.getPastVotes(_account, _timestamp);
    }

    /// @notice The current number of votes required to submit a proposal
    function proposalThreshold() public view returns (uint256) {
        unchecked {
            return (settings.token.totalSupply() * settings.proposalThresholdBps) / 10_000;
        }
    }

    /// @notice The current number of votes required to be in favor of a proposal in order to reach quorum
    function quorum() public view returns (uint256) {
        unchecked {
            return (settings.token.totalSupply() * settings.quorumThresholdBps) / 10_000;
        }
    }

    /// @notice The data stored for a given proposal
    /// @param _proposalId The proposal id
    function getProposal(bytes32 _proposalId) external view returns (Proposal memory) {
        return proposals[_proposalId];
    }

    /// @notice The timestamp when voting starts for a proposal
    /// @param _proposalId The proposal id
    function proposalSnapshot(bytes32 _proposalId) external view returns (uint256) {
        return proposals[_proposalId].voteStart;
    }

    /// @notice The timestamp when voting ends for a proposal
    /// @param _proposalId The proposal id
    function proposalDeadline(bytes32 _proposalId) external view returns (uint256) {
        return proposals[_proposalId].voteEnd;
    }

    /// @notice The vote counts for a proposal
    /// @param _proposalId The proposal id
    function proposalVotes(bytes32 _proposalId)
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        Proposal memory proposal = proposals[_proposalId];

        return (proposal.againstVotes, proposal.forVotes, proposal.abstainVotes);
    }

    /// @notice The timestamp valid to execute a proposal
    /// @param _proposalId The proposal id
    function proposalEta(bytes32 _proposalId) external view returns (uint256) {
        return settings.treasury.timestamp(_proposalId);
    }

    ///                                                          ///
    ///                      GOVERNOR SETTINGS                   ///
    ///                                                          ///

    /// @notice The basis points of the token supply required to create a proposal
    function proposalThresholdBps() external view returns (uint256) {
        return settings.proposalThresholdBps;
    }

    /// @notice The basis points of the token supply required to reach quorum
    function quorumThresholdBps() external view returns (uint256) {
        return settings.quorumThresholdBps;
    }

    /// @notice The amount of time until voting begins after a proposal is created
    function votingDelay() external view returns (uint256) {
        return settings.votingDelay;
    }

    /// @notice The amount of time to vote on a proposal
    function votingPeriod() external view returns (uint256) {
        return settings.votingPeriod;
    }

    /// @notice The address eligible to veto any proposal (address(0) if burned)
    function vetoer() external view returns (address) {
        return settings.vetoer;
    }

    /// @notice The address of the governance token
    function token() external view returns (address) {
        return address(settings.token);
    }

    /// @notice The address of the treasury
    function treasury() external view returns (address) {
        return address(settings.treasury);
    }

    ///                                                          ///
    ///                       UPDATE SETTINGS                    ///
    ///                                                          ///

    /// @notice Updates the voting delay
    /// @param _newVotingDelay The new voting delay
    function updateVotingDelay(uint256 _newVotingDelay) external onlyOwner {
        emit VotingDelayUpdated(settings.votingDelay, _newVotingDelay);

        settings.votingDelay = SafeCast.toUint48(_newVotingDelay);
    }

    /// @notice Updates the voting period
    /// @param _newVotingPeriod The new voting period
    function updateVotingPeriod(uint256 _newVotingPeriod) external onlyOwner {
        emit VotingPeriodUpdated(settings.votingPeriod, _newVotingPeriod);

        settings.votingPeriod = SafeCast.toUint48(_newVotingPeriod);
    }

    /// @notice Updates the minimum proposal threshold
    /// @param _newProposalThresholdBps The new proposal threshold basis points
    function updateProposalThresholdBps(uint256 _newProposalThresholdBps) external onlyOwner {
        emit ProposalThresholdBpsUpdated(settings.proposalThresholdBps, _newProposalThresholdBps);

        settings.proposalThresholdBps = SafeCast.toUint16(_newProposalThresholdBps);
    }

    /// @notice Updates the minimum quorum threshold
    /// @param _newQuorumVotesBps The new quorum votes basis points
    function updateQuorumThresholdBps(uint256 _newQuorumVotesBps) external onlyOwner {
        emit QuorumVotesBpsUpdated(settings.quorumThresholdBps, _newQuorumVotesBps);

        settings.quorumThresholdBps = SafeCast.toUint16(_newQuorumVotesBps);
    }

    /// @notice Updates the vetoer
    /// @param _newVetoer The new vetoer address
    function updateVetoer(address _newVetoer) external onlyOwner {
        if (_newVetoer == address(0)) revert ADDRESS_ZERO();

        emit VetoerUpdated(settings.vetoer, _newVetoer);

        settings.vetoer = _newVetoer;
    }

    /// @notice Burns the vetoer
    function burnVetoer() external onlyOwner {
        emit VetoerUpdated(settings.vetoer, address(0));

        delete settings.vetoer;
    }

    ///                                                          ///
    ///                       GOVERNOR UPGRADE                   ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract and that the new implementation is valid
    /// @dev This function is called in `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The new implementation address
    function _authorizeUpgrade(address _newImpl) internal view override onlyOwner {
        // Ensure the new implementation is a registered upgrade
        if (!manager.isRegisteredUpgrade(_getImplementation(), _newImpl)) revert INVALID_UPGRADE(_newImpl);
    }
}
