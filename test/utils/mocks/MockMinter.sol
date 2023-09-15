// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { IMintStrategy } from "../../../src/minters/interfaces/IMintStrategy.sol";

contract MockMinter is IMintStrategy {
    mapping(address => bytes) public data;

    function setMintSettings(bytes calldata _data) external override {
        data[msg.sender] = _data;
    }
}
