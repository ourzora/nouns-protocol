// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface IGovernor {
    function initialize(
        address _treasury,
        address _token,
        address _vetoer
    ) external;
}
