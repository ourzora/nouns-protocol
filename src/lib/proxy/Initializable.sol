// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {Address} from "../utils/Address.sol";

contract InitializableStorageV1 {
    uint8 internal _initialized;
    bool internal _initializing;
}

abstract contract Initializable is InitializableStorageV1 {
    event Initialized(uint256 version);

    modifier onlyInitializing() {
        require(_initializing, "NOT_INITIALIZING");
        _;
    }

    modifier initializer() {
        bool isTopLevelCall = !_initializing;

        require((isTopLevelCall && _initialized == 0) || (!Address.isContract(address(this)) && _initialized == 1), "INITIALIZED");

        _initialized = 1;

        if (isTopLevelCall) {
            _initializing = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;

            emit Initialized(1);
        }
    }

    modifier reinitializer(uint8 _version) {
        require(!_initializing && _initialized < _version, "INITIALIZED");

        _initialized = _version;

        _initializing = true;

        _;

        _initializing = false;

        emit Initialized(_version);
    }
}
