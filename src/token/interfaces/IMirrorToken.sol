// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title IMirrorToken
/// @author Neokry
/// @notice A token that allows mirroring another token's ownership
interface IMirrorToken {
    /// @notice Mirrors the ownership of a given tokenId from {tokenToMirror}
    /// @param _tokenId The ERC-721 token to mirror
    function mirror(uint256 _tokenId) external;
}
