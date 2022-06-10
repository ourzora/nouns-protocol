// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface IGovernor {
    function initialize(
        address _treasury,
        address _token,
        address _vetoer,
        uint256 _votingPeriod,
        uint256 _votingDelay,
        uint256 _proposalThresholdBPS,
        uint256 _quorumVotesBPS
    ) external;
}
