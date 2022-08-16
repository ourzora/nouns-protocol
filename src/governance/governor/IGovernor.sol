// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

// import {IToken} from "../../token/IToken.sol";

interface IGovernor {
    event ProposalCreated(
        uint256 proposalNumber,
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        bytes[] calldatas,
        uint256 voteStart,
        uint256 voteEnd,
        uint256 proposalThreshold,
        uint256 quorumVotes,
        bytes32 descriptionHash
    );

    event ProposalQueued(uint256 proposalId);

    event ProposalExecuted(uint256 proposalId);

    event ProposalCanceled(uint256 proposalId);

    event ProposalVetoed(uint256 proposalId);

    event VoteCast(address voter, uint256 proposalId, uint256 support, uint256 weight);

    event VotingDelayUpdated(uint256 prevVotingDelay, uint256 newVotingDelay);

    event VotingPeriodUpdated(uint256 prevVotingPeriod, uint256 newVotingPeriod);

    event ProposalThresholdBpsUpdated(uint256 prevBps, uint256 newBps);

    event QuorumVotesBpsUpdated(uint256 prevBps, uint256 newBps);

    event VetoerUpdated(address prevVetoer, address newVetoer);

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    error BELOW_PROPOSAL_THRESHOLD();

    error NO_TARGET_PROVIDED();

    error INVALID_PROPOSAL_LENGTH();

    error PROPOSAL_EXISTS(uint256 proposalId);

    error PROPOSAL_UNSUCCESSFUL();

    error PROPOSAL_NOT_QUEUED(uint256 proposalId, uint256 state);

    error ALREADY_EXECUTED();

    error PROPOSER_ABOVE_THRESHOLD();

    error ONLY_VETOER();

    error INACTIVE_PROPOSAL();

    error ALREADY_VOTED();

    error INVALID_VOTE();

    error INVALID_PROPOSAL();

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function initialize(
        address treasury,
        address token,
        address vetoer,
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 proposalThresholdBPS,
        uint256 quorumVotesBPS
    ) external;

    // function proposalThreshold() external view returns (uint256);

    // function quorum(uint256 timestamp) external view returns (uint256);

    // function votingDelay() external view returns (uint256);

    // function votingPeriod() external view returns (uint256);

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    // function timelock() external view returns (address);

    // function name() external view returns (string memory);

    // function version() external view returns (string memory);

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    // function propose(
    //     address[] memory targets,
    //     uint256[] memory values,
    //     bytes[] memory calldatas,
    //     string memory description
    // ) external returns (uint256 proposalId);

    // function queue(
    //     address[] memory targets,
    //     uint256[] memory values,
    //     bytes[] memory calldatas,
    //     bytes32 descriptionHash
    // ) external returns (uint256 proposalId);

    // function execute(
    //     address[] memory targets,
    //     uint256[] memory values,
    //     bytes[] memory calldatas,
    //     bytes32 descriptionHash
    // ) external payable returns (uint256 proposalId);

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    // function hashProposal(
    //     address[] memory targets,
    //     uint256[] memory values,
    //     bytes[] memory calldatas,
    //     bytes32 descriptionHash
    // ) external pure returns (uint256);

    // enum ProposalState {
    //     Pending,
    //     Active,
    //     Canceled,
    //     Defeated,
    //     Succeeded,
    //     Queued,
    //     Expired,
    //     Executed
    // }

    // function state(uint256 proposalId) external view returns (ProposalState);

    // function proposalEta(uint256 proposalId) external view returns (uint256);

    // function proposalDeadline(uint256 proposalId) external view returns (uint256);

    // function proposalSnapshot(uint256 proposalId) external view returns (uint256);

    // function proposalVotes(uint256 proposalId)
    //     external
    //     view
    //     returns (
    //         uint256 againstVotes,
    //         uint256 forVotes,
    //         uint256 abstainVotes
    //     );

    // function hasVoted(uint256 proposalId, address account) external view returns (bool);

    // function getVotes(address account, uint256 timestamp) external view returns (uint256);

    // function getVotesWithParams(
    //     address account,
    //     uint256 timestamp,
    //     bytes memory params
    // ) external view returns (uint256);

    // function castVote(uint256 proposalId, uint256 support) external returns (uint256 balance);

    // function castVoteBySig(
    //     uint256 proposalId,
    //     uint256 support,
    //     uint8 v,
    //     bytes32 r,
    //     bytes32 s
    // ) external returns (uint256 balance);

    // function owner() external view returns (address);
}
