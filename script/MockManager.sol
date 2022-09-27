// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Ownable } from "../src/lib/utils/Ownable.sol";
import { UUPS } from "../src/lib/proxy/UUPS.sol";

contract MockManager is Ownable, UUPS {
    function initialize() initializer public {
        __Ownable_init(msg.sender);
    }

    function _authorizeUpgrade(address _newImpl) internal view override onlyOwner {}
}
