// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {MockImpl} from "./MockImpl.sol";

contract MockPartialTokenImpl is MockImpl {
    function onFirstAuctionStarted() external {}
}