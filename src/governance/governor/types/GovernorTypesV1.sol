// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Token } from "../../../token/Token.sol";
import { Treasury } from "../../treasury/Treasury.sol";

/// @title GovernorTypesV1
/// @author Rohan Kulkarni
/// @notice The Governor custom data types
interface GovernorTypesV1 {
    /// @notice The governor settings
    /// @param token The governance token
    /// @param proposalThresholdBps The minimum votes (in basis points of the total supply) required to submit a proposal
    /// @param quorumThresholdBps The minimum votes (in basis points of total supply) required to reach quorum
    /// @param treasury The treasury controller
    /// @param votingDelay The amount of time after a proposal until voting begins
    /// @param votingPeriod The amount of time voting takes place for an active proposal
    /// @param vetoer The address with the ability to veto proposals
    struct Settings {
        Token token;
        uint16 proposalThresholdBps;
        uint16 quorumThresholdBps;
        Treasury treasury;
        uint48 votingDelay;
        uint48 votingPeriod;
        address vetoer;
    }

    /// @notice A governance proposal
    /// @param proposer The proposal creator
    /// @param timeCreated The timestamp that the proposal was created
    /// @param againstVotes The number of votes against
    /// @param forVotes The number of votes in favor
    /// @param abstainVotes The number of votes abstained
    /// @param voteStart The timestamp that voting starts
    /// @param voteEnd The timestamp that voting ends
    /// @param proposalThreshold The proposal threshold when the proposal was created
    /// @param quorumVotes The quorum threshold when the proposal was created
    /// @param executed If the proposal was executed
    /// @param canceled If the proposal was canceled
    /// @param vetoed If the proposal was vetoed
    struct Proposal {
        address proposer;
        uint32 timeCreated;
        uint32 againstVotes;
        uint32 forVotes;
        uint32 abstainVotes;
        uint32 voteStart;
        uint32 voteEnd;
        uint32 proposalThreshold;
        uint32 quorumVotes;
        bool executed;
        bool canceled;
        bool vetoed;
    }

    /// @notice The proposal state type
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
}
