// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

contract TokenStorageV1 {
    /// @notice The metadata type of the founders DAO
    /// @dev `uint32` holds a max value of 4,294,967,295 tokens
    /// @param DAO The founders DAO address
    /// @param maxAllocation The maximum number of tokens that will be vested
    /// @param currentAllocation The current number of tokens vested
    /// @param allocationFrequency The interval between tokens to vest to the founders
    struct Founders {
        address DAO;
        uint32 maxAllocation;
        uint32 currentAllocation;
        uint32 allocationFrequency;
    }

    /// @notice The metadata of the founders DAO
    Founders public founders;

    /// @notice The address of the minter
    address public minter;

    /// @notice The token id tracker
    uint256 public tokenCount;
}
