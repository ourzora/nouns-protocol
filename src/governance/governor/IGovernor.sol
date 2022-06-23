// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

interface IGovernor {
    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function initialize(
        address treasury,
        address token,
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 proposalThresholdBPS,
        uint256 quorumVotesBPS
    ) external;

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function proposalThreshold() external view returns (uint256);

    function quorum(uint256 blockNumber) external view returns (uint256);

    function votingDelay() external view returns (uint256);

    function votingPeriod() external view returns (uint256);

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function COUNTING_MODE() external pure returns (string memory);

    function timelock() external view returns (address);

    function name() external view returns (string memory);

    function version() external view returns (string memory);

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256 proposalId);

    function queue(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external returns (uint256 proposalId);

    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external payable returns (uint256 proposalId);

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external pure returns (uint256);

    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    function state(uint256 proposalId) external view returns (ProposalState);

    function proposalEta(uint256 proposalId) external view returns (uint256);

    function proposalDeadline(uint256 proposalId) external view returns (uint256);

    function proposalSnapshot(uint256 proposalId) external view returns (uint256);

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function proposalVotes(uint256 proposalId)
        external
        view
        returns (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        );

    function hasVoted(uint256 proposalId, address account) external view returns (bool);

    function getVotes(address account, uint256 blockNumber) external view returns (uint256);

    function getVotesWithParams(
        address account,
        uint256 blockNumber,
        bytes memory params
    ) external view returns (uint256);

    function castVote(uint256 proposalId, uint8 support) external returns (uint256 balance);

    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external returns (uint256 balance);

    function castVoteWithReasonAndParams(
        uint256 proposalId,
        uint8 support,
        string calldata reason,
        bytes memory params
    ) external returns (uint256 balance);

    function castVoteBySig(
        uint256 proposalId,
        uint8 support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 balance);

    function castVoteWithReasonAndParamsBySig(
        uint256 proposalId,
        uint8 support,
        string calldata reason,
        bytes memory params,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 balance);

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function owner() external view returns (address);

    function transferOwnership(address newOwner) external;

    function renounceOwnership() external;

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function upgradeTo(address newImplementation) external;

    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
}
