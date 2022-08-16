// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

contract TokenTypesV1 {
    struct Founder {
        uint32 allocationFrequency;
        uint64 vestingEnd;
        address wallet;
    }
}
