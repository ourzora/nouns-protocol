// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { IBaseMetadata } from "../metadata/interfaces/IBaseMetadata.sol";

/// @title TokenTypesV1
/// @author Rohan Kulkarni
/// @notice The Token custom data types
interface TokenTypesV1 {
    /// @notice The settings type
    /// @param auction The DAO auction house
    /// @param totalSupply The number of tokens minted
    /// @param metadatarenderer The token metadata renderer
    /// @param numFounders The number of vesting recipients
    /// @param totalPercentage The total percentage owned by founders
    struct Settings {
        address auction;
        uint96 totalSupply;
        IBaseMetadata metadataRenderer;
        uint16 numFounders;
        uint8 totalPercentage;
    }

    /// @notice The founder type
    /// @param wallet The address where tokens are sent
    /// @param percentage The percentage of token ownership
    /// @param vestingEnd The timestamp when vesting ends
    struct Founder {
        address wallet;
        uint8 percentage;
        uint32 vestingEnd;
    }
}
