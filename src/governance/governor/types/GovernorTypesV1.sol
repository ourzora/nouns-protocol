// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {Token} from "../../../token/Token.sol";
import {Timelock} from "../../timelock/Timelock.sol";

contract GovernorTypesV1 {
    struct Settings {
        Token token; // The governance token
        uint64 proposalCount; // The number of created proposals
        uint16 proposalThresholdBps; // The number of votes required for a voter to become a proposer
        uint16 quorumVotesBps; // The number of votes required to support a proposal
        Timelock timelock; // The timelock controller
        uint48 votingDelay; // The amount of time after a proposal until voting begins
        uint48 votingPeriod; // The amount of time that voting for a proposal takes place
        address vetoer; // The address elgibile to veto proposals
    }

    struct Proposal {
        address proposer;
        uint32 againstVotes; // The number of votes against the proposal
        uint32 forVotes; // The number of votes for the proposal
        uint32 abstainVotes; // The number of votes abstaining from the proposal
        uint64 voteStart; // The timestamp that voting starts
        uint64 voteEnd; // The timestamp that voting ends
        uint32 proposalThreshold;
        uint32 quorumVotes;
        bool executed;
        bool canceled;
        bool vetoed;
    }

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
