// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {ECDSA} from "./ECDSA.sol";
import {Initializable} from "../proxy/Initializable.sol";

contract EIP712StorageV1 {
    bytes32 internal _HASHED_NAME;
    bytes32 internal _HASHED_VERSION;

    bytes32 internal INITIAL_DOMAIN_SEPARATOR;
    uint256 internal INITIAL_CHAIN_ID;
}

abstract contract EIP712 is Initializable, EIP712StorageV1 {
    bytes32 internal constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    function __EIP712_init(string memory _name, string memory _version) internal onlyInitializing {
        _HASHED_NAME = keccak256(bytes(_name));
        _HASHED_VERSION = keccak256(bytes(_version));

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();
    }

    function _hashTypedDataV4(bytes32 _structHash) internal view virtual returns (bytes32) {
        return ECDSA.toTypedDataHash(DOMAIN_SEPARATOR(), _structHash);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : _computeDomainSeparator();
    }

    function _computeDomainSeparator() internal view virtual returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_TYPEHASH, _HASHED_NAME, _HASHED_VERSION, block.chainid, address(this)));
    }
}
