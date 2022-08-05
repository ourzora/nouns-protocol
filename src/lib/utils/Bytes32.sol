// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

library Bytes32 {
    function toString(bytes32 _value) internal pure returns (string memory) {
        return string(abi.encodePacked(_value));
    }
}
