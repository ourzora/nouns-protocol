// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {UUPS} from "../../lib/proxy/UUPS.sol";
import {Ownable} from "../../lib/utils/Ownable.sol";
import {Address} from "../../lib/utils/Address.sol";
import {EIP712} from "../../lib/utils/EIP712.sol";
import {Cast} from "../../lib/utils/Cast.sol";

import {GovernorStorageV1} from "./storage/GovernorStorageV1.sol";
import {Token} from "../../token/Token.sol";
import {Timelock} from "../timelock/Timelock.sol";

import {IManager} from "../../manager/IManager.sol";
import {IGovernor} from "./IGovernor.sol";

/// @title Governor
/// @author Rohan Kulkarni
/// @notice This contract DAO governor
contract Governor is IGovernor, UUPS, Ownable, EIP712, GovernorStorageV1 {
    ///                                                          ///
    ///                         CONSTANTS                        ///
    ///                                                          ///

    /// @notice The typehash for casting a vote with a signature
    bytes32 public constant VOTE_TYPEHASH = keccak256("Vote(address voter,uint256 proposalId,uint256 support,uint256 nonce,uint256 deadline)");

    ///                                                          ///
    ///                         IMMUTABLES                       ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IManager private immutable manager;

    ///                                                          ///
    ///                         CONSTRUCTOR                      ///
    ///                                                          ///

    /// @param _manager The address of the contract upgrade manager
    constructor(address _manager) payable initializer {
        manager = IManager(_manager);
    }

    ///                                                          ///
    ///                          INITIALIZER                     ///
    ///                                                          ///

    /// @notice Initializes a DAO governor
    function initialize(
        address _timelock,
        address _token,
        address _vetoer,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThresholdBPS,
        uint256 _quorumVotesBPS
    ) external initializer {
        if (_timelock == address(0)) revert ADDRESS_ZERO();
        if (_token == address(0)) revert ADDRESS_ZERO();

        settings.timelock = Timelock(payable(_timelock));
        settings.token = Token(_token);
        settings.vetoer = _vetoer;
        settings.votingDelay = Cast.toUint48(_votingDelay);
        settings.votingPeriod = Cast.toUint48(_votingPeriod);
        settings.proposalThresholdBps = Cast.toUint16(_proposalThresholdBPS);
        settings.quorumVotesBps = Cast.toUint16(_quorumVotesBPS);

        __EIP712_init(string.concat(settings.token.symbol(), " GOV"), "1");
        __Ownable_init(_timelock);
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    ///
    function hashProposal(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    ) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(_targets, _values, _calldatas, _descriptionHash)));
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function propose(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description
    ) external returns (uint256) {
        if (_getVotes(msg.sender, block.timestamp - 1) < proposalThreshold()) revert BELOW_PROPOSAL_THRESHOLD();

        uint256 numTargets = _targets.length;

        if (numTargets == 0) revert NO_TARGET_PROVIDED();
        if (numTargets != _values.length) revert INVALID_PROPOSAL_LENGTH();
        if (numTargets != _calldatas.length) revert INVALID_PROPOSAL_LENGTH();

        bytes32 descriptionHash = keccak256(bytes(_description));
        uint256 proposalId = hashProposal(_targets, _values, _calldatas, descriptionHash);

        Proposal storage proposal = proposals[proposalId];

        if (proposal.voteStart != 0) revert PROPOSAL_EXISTS(proposalId);

        uint256 snapshot;
        uint256 deadline;

        unchecked {
            ++settings.proposalCount;

            snapshot = block.timestamp + settings.votingDelay;
            deadline = snapshot + settings.votingPeriod;
        }

        proposal.voteStart = uint64(snapshot);
        proposal.voteEnd = uint64(deadline);
        proposal.proposalThreshold = uint32(proposalThreshold());
        proposal.quorumVotes = uint32(quorumVotes());
        proposal.proposer = msg.sender;

        emit ProposalCreated(
            settings.proposalCount,
            proposalId,
            msg.sender,
            _targets,
            _values,
            _calldatas,
            snapshot,
            deadline,
            proposal.proposalThreshold,
            proposal.quorumVotes,
            descriptionHash
        );

        return proposalId;
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function queue(uint256 _proposalId) external returns (uint256) {
        if (state(_proposalId) != ProposalState.Succeeded) revert PROPOSAL_UNSUCCESSFUL();

        settings.timelock.schedule(_proposalId);

        emit ProposalQueued(_proposalId);

        return _proposalId;
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function execute(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    ) external payable returns (uint256) {
        uint256 proposalId = hashProposal(_targets, _values, _calldatas, _descriptionHash);

        ProposalState status = state(proposalId);

        // require(status == ProposalState.Queued, "Governor: proposal not queued");
        if (status != ProposalState.Queued) revert PROPOSAL_NOT_QUEUED(proposalId, uint256(status));

        proposals[proposalId].executed = true;

        settings.timelock.execute{value: msg.value}(_targets, _values, _calldatas, _descriptionHash);

        emit ProposalExecuted(proposalId);

        return proposalId;
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function cancel(uint256 _proposalId) external {
        // require(state(_proposalId) != ProposalState.Executed, "");
        if (state(_proposalId) == ProposalState.Executed) revert ALREADY_EXECUTED();

        Proposal memory proposal = proposals[_proposalId];

        unchecked {
            // require(msg.sender == proposal.proposer || _getVotes(proposal.proposer, block.timestamp - 1) < proposal.proposalThreshold, "");
            if (msg.sender != proposal.proposer && _getVotes(proposal.proposer, block.timestamp - 1) > proposal.proposalThreshold)
                revert PROPOSER_ABOVE_THRESHOLD();
        }

        proposals[_proposalId].canceled = true;

        if (settings.timelock.isQueued(_proposalId)) {
            settings.timelock.cancel(_proposalId);
        }

        emit ProposalCanceled(_proposalId);
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function veto(uint256 _proposalId) external {
        if (msg.sender != settings.vetoer) revert ONLY_VETOER();
        if (state(_proposalId) == ProposalState.Executed) revert ALREADY_EXECUTED();

        Proposal storage proposal = proposals[_proposalId];

        proposal.vetoed = true;

        if (settings.timelock.isQueued(_proposalId)) {
            settings.timelock.cancel(_proposalId);
        }

        emit ProposalVetoed(_proposalId);
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function castVote(uint256 _proposalId, uint256 _support) public returns (uint256) {
        return _castVote(_proposalId, msg.sender, _support);
    }

    function castVoteBySig(
        address _voter,
        uint256 _proposalId,
        uint256 _support,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public returns (uint256) {
        if (block.timestamp > _deadline) revert EXPIRED_SIGNATURE();

        bytes32 digest;

        unchecked {
            digest = keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(VOTE_TYPEHASH, _voter, _proposalId, _support, nonces[_voter]++, _deadline))
                )
            );
        }

        address recoveredAddress = ecrecover(digest, _v, _r, _s);

        if (recoveredAddress == address(0) || recoveredAddress != _voter) revert INVALID_SIGNER();

        return _castVote(_proposalId, _voter, _support);
    }

    function _castVote(
        uint256 _proposalId,
        address _user,
        uint256 _support
    ) internal returns (uint256) {
        // require(state(_proposalId) == ProposalState.Active, "INACTIVE_PROPOSAL");
        // require(!hasVoted[_proposalId][_user], "ALREADY_VOTED");
        // require(_support <= 2, "INVALID_VOTE");

        if (state(_proposalId) != ProposalState.Active) revert INACTIVE_PROPOSAL();
        if (hasVoted[_proposalId][_user]) revert ALREADY_VOTED();
        if (_support > 2) revert INVALID_VOTE();

        Proposal storage proposal = proposals[_proposalId];

        uint256 weight;

        unchecked {
            weight = _getVotes(_user, proposal.voteStart - settings.votingDelay);

            if (_support == 0) {
                proposal.againstVotes += uint32(weight);

                //
            } else if (_support == 1) {
                proposal.forVotes += uint32(weight);

                //
            } else if (_support == 2) {
                proposal.abstainVotes += uint32(weight);
            }
        }

        hasVoted[_proposalId][_user] = true;

        emit VoteCast(_user, _proposalId, _support, weight);

        return weight;
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function state(uint256 _proposalId) public view returns (ProposalState) {
        Proposal memory proposal = proposals[_proposalId];

        if (proposal.voteStart == 0) revert INVALID_PROPOSAL();

        if (proposal.executed) {
            return ProposalState.Executed;
        } else if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (proposal.vetoed) {
            return ProposalState.Vetoed;
        } else if (proposal.voteStart >= block.timestamp) {
            return ProposalState.Pending;
        } else if (proposal.voteEnd >= block.timestamp) {
            return ProposalState.Active;
        } else if (proposal.forVotes < proposal.againstVotes || proposal.forVotes < proposal.quorumVotes) {
            return ProposalState.Defeated;
        } else if (!settings.timelock.isQueued(_proposalId)) {
            return ProposalState.Succeeded;
        } else if (settings.timelock.isExpired(_proposalId)) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function _getVotes(address _account, uint256 _timestamp) internal view returns (uint256) {
        return settings.token.getPastVotes(_account, _timestamp);
    }

    function _bpsToUint(uint256 _number, uint256 _bps) internal pure returns (uint256 result) {
        assembly {
            result := div(mul(_number, _bps), 10000)
        }
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function proposalThreshold() public view returns (uint256) {
        return _bpsToUint(settings.token.totalSupply(), settings.proposalThresholdBps);
    }

    function quorumVotes() public view returns (uint256) {
        return _bpsToUint(settings.token.totalSupply(), settings.quorumVotesBps);
    }

    function proposalSnapshot(uint256 _proposalId) public view returns (uint256) {
        return proposals[_proposalId].voteStart;
    }

    function proposalDeadline(uint256 _proposalId) public view returns (uint256) {
        return proposals[_proposalId].voteEnd;
    }

    function proposalEta(uint256 _proposalId) public view returns (uint256) {
        return settings.timelock.timestamps(_proposalId);
    }

    function proposalVotes(uint256 _proposalId)
        public
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

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function votingDelay() external view returns (uint256) {
        return settings.votingDelay;
    }

    function votingPeriod() external view returns (uint256) {
        return settings.votingPeriod;
    }

    function proposalThresholdBps() external view returns (uint256) {
        return settings.proposalThresholdBps;
    }

    function quorumVotesBps() external view returns (uint256) {
        return settings.quorumVotesBps;
    }

    function vetoer() public view returns (address) {
        return settings.vetoer;
    }

    function token() public view returns (address) {
        return address(settings.token);
    }

    function timelock() public view returns (address) {
        return address(settings.timelock);
    }

    ///                                                          ///
    ///                       UPDATE SETTINGS                    ///
    ///                                                          ///

    function updateVotingDelay(uint256 _newVotingDelay) external onlyOwner {
        emit VotingDelayUpdated(settings.votingDelay, _newVotingDelay);

        settings.votingDelay = Cast.toUint48(_newVotingDelay);
    }

    function updateVotingPeriod(uint256 _newVotingPeriod) external onlyOwner {
        emit VotingPeriodUpdated(settings.votingPeriod, _newVotingPeriod);

        settings.votingPeriod = Cast.toUint48(_newVotingPeriod);
    }

    function updateProposalThresholdBps(uint256 _newProposalThresholdBps) external onlyOwner {
        emit ProposalThresholdBpsUpdated(settings.proposalThresholdBps, _newProposalThresholdBps);

        settings.proposalThresholdBps = Cast.toUint16(_newProposalThresholdBps);
    }

    function updateQuorumVotesBps(uint256 _newQuorumVotesBps) external onlyOwner {
        emit QuorumVotesBpsUpdated(settings.quorumVotesBps, _newQuorumVotesBps);

        settings.quorumVotesBps = Cast.toUint16(_newQuorumVotesBps);
    }

    function updateVetoer(address _vetoer) external onlyOwner {
        if (_vetoer == address(0)) revert ADDRESS_ZERO();

        emit VetoerUpdated(settings.vetoer, _vetoer);

        settings.vetoer = _vetoer;
    }

    function burnVetoer() external onlyOwner {
        emit VetoerUpdated(settings.vetoer, address(0));

        delete settings.vetoer;
    }

    ///                                                          ///
    ///                       CONTRACT UPGRADE                   ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract and that the new implementation is valid
    /// @dev This function is called in `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The address of the new implementation
    function _authorizeUpgrade(address _newImpl) internal view override onlyOwner {
        // Ensure the new implementation is a registered upgrade
        if (!manager.isValidUpgrade(_getImplementation(), _newImpl)) revert INVALID_UPGRADE(_newImpl);
    }
}
