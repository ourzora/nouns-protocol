// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {Initializable} from "../proxy/Initializable.sol";

contract ReentrancyGuardStorageV1 {
    uint256 internal _status;
}

abstract contract ReentrancyGuard is Initializable, ReentrancyGuardStorageV1 {
    uint256 internal constant _NOT_ENTERED = 1;
    uint256 internal constant _ENTERED = 2;

    function __ReentrancyGuard_init() internal onlyInitializing {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "REENTRANCY");

        _status = _ENTERED;

        _;

        _status = _NOT_ENTERED;
    }
}
