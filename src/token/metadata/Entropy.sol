// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

contract Entropy {
    function _getEntropy(uint256 seed) internal view returns (uint256) {
        return uint256(keccak256(abi.encode(seed, blockhash(block.number), block.coinbase, block.timestamp)));
    }
}
