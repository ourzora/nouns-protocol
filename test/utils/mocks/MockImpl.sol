// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { UUPS } from "../../../src/lib/proxy/UUPS.sol";

contract MockImpl is UUPS {
    function _authorizeUpgrade(address _newImpl) internal view override {}
}
