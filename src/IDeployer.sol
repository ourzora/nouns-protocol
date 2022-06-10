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
}
