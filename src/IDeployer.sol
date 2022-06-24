// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

interface IDeployer {
    struct TokenParams {
        string name;
        string symbol;
        address foundersDAO;
        uint256 foundersMaxAllocation;
        uint256 foundersAllocationFrequency;
    }

    struct AuctionParams {
        uint256 timeBuffer;
        uint256 reservePrice;
        uint256 minBidIncrementPercentage;
        uint256 duration;
    }

    struct GovParams {
        uint256 timelockDelay;
        uint256 votingDelay;
        uint256 votingPeriod;
        uint256 proposalThresholdBPS;
        uint256 quorumVotesBPS;
    }

    function deploy(
        TokenParams calldata _tokenParams,
        AuctionParams calldata _auctionParams,
        GovParams calldata _govParams
    )
        external
        returns (
            address token,
            address auction,
            address treasury,
            address governor
        );
}
