// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { IBaseMetadata } from "../metadata/interfaces/IBaseMetadata.sol";

/// @title TokenTypesV1
/// @author Rohan Kulkarni
/// @notice The Token custom data types
interface TokenTypesV1 {
    /// @notice The settings type
    /// @param auction The DAO auction house
    /// @param totalSupply The number of active tokens
    /// @param numFounders The number of vesting recipients
    /// @param metadatarenderer The token metadata renderer
    /// @param mintCount The number of minted tokens
    /// @param totalPercentage The total percentage owned by founders
    struct Settings {
        address auction;
        uint88 totalSupply;
        uint8 numFounders;
        IBaseMetadata metadataRenderer;
        uint88 mintCount;
        uint8 totalOwnership;
    }

    /// @notice The founder type
    /// @param wallet The address where tokens are sent
    /// @param ownershipPct The percentage of token ownership
    /// @param vestExpiry The timestamp when vesting ends
    struct Founder {
        address wallet;
        uint8 ownershipPct;
        uint32 vestExpiry;
    }
}
