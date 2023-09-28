// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import { IBaseMetadata } from "../src/metadata/interfaces/IBaseMetadata.sol";
import { IPropertyMetadata } from "../src/metadata/property/interfaces/IPropertyMetadata.sol";
import { IMirrorToken } from "../src/token/interfaces/IMirrorToken.sol";

contract GetInterfaceIds is Script {
    function run() public view {
        console2.logBytes4(type(IBaseMetadata).interfaceId);
        console2.logBytes4(type(IPropertyMetadata).interfaceId);
        console2.logBytes4(type(IMirrorToken).interfaceId);
    }
}
