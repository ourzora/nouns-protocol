// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title EIP712StorageV1
/// @author Rohan Kulkarni
/// @notice The storage for EIP712
contract EIP712StorageV1 {
    /// @notice The hash of the EIP-712 domain name
    bytes32 internal HASHED_NAME;

    /// @notice The hash of the EIP-712 domain version
    bytes32 internal HASHED_VERSION;

    /// @notice The domain separator computed upon initialization
    bytes32 internal INITIAL_DOMAIN_SEPARATOR;

    /// @notice The chain id upon initialization
    uint256 internal INITIAL_CHAIN_ID;

    /// @notice The current nonce for an account
    /// @dev Account => Nonce
    mapping(address => uint256) internal nonces;
}
