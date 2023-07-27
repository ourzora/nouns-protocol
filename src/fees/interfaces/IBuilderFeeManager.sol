// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IBuilderFeeManager {
    function getBuilderFeesBPS(address sender) external returns (address payable, uint256);
}
