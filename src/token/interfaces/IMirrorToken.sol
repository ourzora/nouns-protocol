// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title IMirrorToken
/// @author Neokry
/// @notice A token that allows mirroring another token's ownership
interface IMirrorToken {
    /// @notice Gets the token address being mirrored
    /// @return The token address being mirrored
    function getTokenToMirror() external view returns (address);

    /// @notice Mirrors the ownership of a given tokenId
    /// @param _tokenId The ERC-721 token to mirror
    function mirror(uint256 _tokenId) external;
}
