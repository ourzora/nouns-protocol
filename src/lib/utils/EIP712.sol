// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {Initializable} from "../proxy/Initializable.sol";

contract EIP712StorageV1 {
    bytes32 internal _HASHED_NAME;
    bytes32 internal _HASHED_VERSION;

    bytes32 internal INITIAL_DOMAIN_SEPARATOR;
    uint256 internal INITIAL_CHAIN_ID;

    mapping(address => uint256) public nonces;
}

/// @notice Modified from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/draft-EIP712.sol
abstract contract EIP712 is Initializable, EIP712StorageV1 {
    bytes32 private constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    error EXPIRED_SIGNATURE();

    error INVALID_SIGNER();

    function __EIP712_init(string memory _name, string memory _version) internal onlyInitializing {
        _HASHED_NAME = keccak256(bytes(_name));
        _HASHED_VERSION = keccak256(bytes(_version));

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : _computeDomainSeparator();
    }

    function _computeDomainSeparator() private view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_TYPEHASH, _HASHED_NAME, _HASHED_VERSION, block.chainid, address(this)));
    }
}
