// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {Initializable} from "../proxy/Initializable.sol";

contract PausableStorageV1 {
    bool public paused;
}

abstract contract Pausable is Initializable, PausableStorageV1 {
    function __Pausable_init(bool _paused) internal onlyInitializing {
        paused = _paused;
    }

    modifier whenPaused() {
        require(paused, "NOT_PAUSED");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "PAUSED");
        _;
    }

    event Paused(address user);

    function _pause() internal virtual whenNotPaused {
        paused = true;

        emit Paused(msg.sender);
    }

    event Unpaused(address user);

    function _unpause() internal virtual whenPaused {
        paused = false;

        emit Unpaused(msg.sender);
    }
}
