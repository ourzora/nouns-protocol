// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {Initializable} from "../proxy/Initializable.sol";

contract PausableStorageV1 {
    bool public paused;
}

/// @notice Modified from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/Pausable.sol
abstract contract Pausable is Initializable, PausableStorageV1 {
    event Paused(address user);

    event Unpaused(address user);

    error PAUSED();

    error UNPAUSED();

    function __Pausable_init(bool _paused) internal onlyInitializing {
        paused = _paused;
    }

    modifier whenPaused() {
        if (!paused) revert UNPAUSED();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert PAUSED();
        _;
    }

    function _pause() internal virtual whenNotPaused {
        paused = true;

        emit Paused(msg.sender);
    }

    function _unpause() internal virtual whenPaused {
        paused = false;

        emit Unpaused(msg.sender);
    }
}
