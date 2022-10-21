// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { IEIP712 } from "../interfaces/IEIP712.sol";
import { Initializable } from "../utils/Initializable.sol";

/// @title EIP712
/// @author Rohan Kulkarni
/// @notice Modified from OpenZeppelin Contracts v4.7.3 (utils/cryptography/draft-EIP712Upgradeable.sol)
/// - Uses custom errors declared in IEIP712
/// - Caches `INITIAL_CHAIN_ID` and `INITIAL_DOMAIN_SEPARATOR` upon initialization
/// - Adds mapping for account nonces
abstract contract EIP712 is IEIP712, Initializable {
    ///                                                          ///
    ///                          CONSTANTS                       ///
    ///                                                          ///

    /// @dev The EIP-712 domain typehash
    bytes32 internal constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    ///                                                          ///
    ///                           STORAGE                        ///
    ///                                                          ///

    /// @notice The hash of the EIP-712 domain name
    bytes32 internal HASHED_NAME;

    /// @notice The hash of the EIP-712 domain version
    bytes32 internal HASHED_VERSION;

    /// @notice The domain separator computed upon initialization
    bytes32 internal INITIAL_DOMAIN_SEPARATOR;

    /// @notice The chain id upon initialization
    uint256 internal INITIAL_CHAIN_ID;

    /// @notice The account nonces
    /// @dev Account => Nonce
    mapping(address => uint256) internal nonces;

    ///                                                          ///
    ///                           FUNCTIONS                      ///
    ///                                                          ///

    /// @dev Initializes EIP-712 support
    /// @param _name The EIP-712 domain name
    /// @param _version The EIP-712 domain version
    function __EIP712_init(string memory _name, string memory _version) internal onlyInitializing {
        HASHED_NAME = keccak256(bytes(_name));
        HASHED_VERSION = keccak256(bytes(_version));

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();
    }

    /// @notice The current nonce for an account
    /// @param _account The account address
    function nonce(address _account) external view returns (uint256) {
        return nonces[_account];
    }

    /// @notice The EIP-712 domain separator
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : _computeDomainSeparator();
    }

    /// @dev Computes the EIP-712 domain separator
    function _computeDomainSeparator() private view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_TYPEHASH, HASHED_NAME, HASHED_VERSION, block.chainid, address(this)));
    }
}
