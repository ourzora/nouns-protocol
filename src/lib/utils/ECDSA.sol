// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {Strings} from "./Strings.sol";

library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV
    }

    function _throwError(RecoverError _error) private pure {
        if (_error == RecoverError.NoError) {
            return;
        } else if (_error == RecoverError.InvalidSignature) {
            revert("INVALID_SIG");
        } else if (_error == RecoverError.InvalidSignatureLength) {
            revert("INVALID_SIG_LENGTH");
        } else if (_error == RecoverError.InvalidSignatureS) {
            revert("INVALID_SIG_'s'");
        } else if (_error == RecoverError.InvalidSignatureV) {
            revert("INVALID_SIG_'v'");
        }
    }

    /// @dev Returns the address that signed a hashed message (`hash`) with `signature` or error string.
    function tryRecover(bytes32 _hash, bytes memory _signature) internal pure returns (address, RecoverError) {
        if (_signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;

            assembly {
                r := mload(add(_signature, 0x20))
                s := mload(add(_signature, 0x40))
                v := byte(0, mload(add(_signature, 0x60)))
            }

            return tryRecover(_hash, v, r, s);
        } else if (_signature.length == 64) {
            bytes32 r;
            bytes32 vs;

            assembly {
                r := mload(add(_signature, 0x20))
                vs := mload(add(_signature, 0x40))
            }
            return tryRecover(_hash, r, vs);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    function tryRecover(
        bytes32 _hash,
        bytes32 _r,
        bytes32 _vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s = _vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint8 v = uint8((uint256(_vs) >> 255) + 27);

        return tryRecover(_hash, v, _r, s);
    }

    function tryRecover(
        bytes32 _hash,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) internal pure returns (address, RecoverError) {
        if (uint256(_s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }
        if (_v != 27 && _v != 28) {
            return (address(0), RecoverError.InvalidSignatureV);
        }

        address signer = ecrecover(_hash, _v, _r, _s);

        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    function recover(
        bytes32 _hash,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(_hash, _v, _r, _s);
        _throwError(error);
        return recovered;
    }

    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", Strings.toString(s.length), s));
    }

    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}
