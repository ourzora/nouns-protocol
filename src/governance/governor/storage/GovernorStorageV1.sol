// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {ITreasury} from "../../treasury/ITreasury.sol";
import {IToken} from "../../../token/IToken.sol";

/// @title Governor Storage V1
/// @author Rohan Kulkarni
/// @notice Modified version of NounsDAOInterfaces.sol (commit 2cbe6c7) that NounsDAO licensed under the GPL-3.0 license
contract GovernorStorageV1 {
    /// @notice The address of the DAO treasury
    ITreasury public treasury;

    /// @notice The address of the token
    IToken public token;

    /// @notice The number of blocks that voting is delayed after a proposal
    uint256 internal VOTING_DELAY;

    /// @notice The number of blocks that voting takes place after a proposal
    uint256 internal VOTING_PERIOD;

    /// @notice The number of votes required in order for a voter to become a proposer
    uint256 internal PROPOSAL_THRESHOLD_BPS;

    /// @notice The number of votes required to support a proposal in order for a quorum to be reached and for a vote to succeed
    uint256 internal QUORUM_VOTES_BPS;
}
