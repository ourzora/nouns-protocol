// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title IMintStrategy
/// @notice The interface for external token minting strategies
/// @author @neokry
interface IMintStrategy {
    /// @notice Sets the mint settings for a token
    /// @param data The encoded mint settings
    function setMintSettings(bytes calldata data) external;
}
