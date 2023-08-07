// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IBuilderFeeManager {
    function getBuilderFeesBPS() external returns (address payable, uint256);
}
