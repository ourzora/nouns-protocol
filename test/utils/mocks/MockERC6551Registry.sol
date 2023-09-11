// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { IERC6551Registry } from "../../../src/lib/interfaces/IERC6551Registry.sol";
import { MockERC1271 } from "./MockERC1271.sol";

contract MockERC6551Registry is IERC6551Registry {
    address immutable owner;

    constructor(address _owner) {
        owner = _owner;
    }

    function createAccount(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 seed,
        bytes calldata initData
    ) external override returns (address) {
        address accountAddr = getAddress(owner, tokenId);

        return accountAddr.code.length == 0 ? address(new MockERC1271{ salt: bytes32(tokenId) }(owner)) : accountAddr;
    }

    function account(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt
    ) external view override returns (address) {
        return getAddress(owner, tokenId);
    }

    function getBytecode(address _owner) public pure returns (bytes memory) {
        bytes memory bytecode = type(MockERC1271).creationCode;
        return abi.encodePacked(bytecode, abi.encode(_owner));
    }

    function getAddress(address _owner, uint256 _salt) public view returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(getBytecode(_owner))));
        return address(uint160(uint256(hash)));
    }
}
