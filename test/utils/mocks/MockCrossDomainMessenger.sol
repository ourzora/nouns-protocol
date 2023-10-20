// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { ICrossDomainMessenger } from "../../../src/deployers/interfaces/ICrossDomainMessenger.sol";

contract MockCrossDomainMessenger is ICrossDomainMessenger {
    address sender;

    constructor(address _sender) {
        sender = _sender;
    }

    function xDomainMessageSender() external view override returns (address) {
        return sender;
    }
}
