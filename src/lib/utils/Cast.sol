// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

library Cast {
    error UNSAFE_CAST();

    function toUint48(uint256 x) internal pure returns (uint48) {
        if (x > (1 << 48)) revert UNSAFE_CAST();

        return uint48(x);
    }

    function toUint40(uint256 x) internal pure returns (uint40) {
        if (x > (1 << 40)) revert UNSAFE_CAST();

        return uint40(x);
    }

    function toUint16(uint256 x) internal pure returns (uint16) {
        if (x > (1 << 16)) revert UNSAFE_CAST();

        return uint16(x);
    }

    function toUint8(uint256 x) internal pure returns (uint8) {
        if (x > (1 << 8)) revert UNSAFE_CAST();

        return uint8(x);
    }

    function toBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function toString(bytes32 _value) internal pure returns (string memory) {
        return string(abi.encodePacked(_value));
    }
}
