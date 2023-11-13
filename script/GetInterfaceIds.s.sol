// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import { OPAddressAliasHelper } from "../src/lib/utils/OPAddressAliasHelper.sol";
import { IBaseMetadata } from "../src/token/metadata/interfaces/IBaseMetadata.sol";
import { IPropertyIPFSMetadataRenderer } from "../src/token/metadata/interfaces/IPropertyIPFSMetadataRenderer.sol";

contract GetInterfaceIds is Script {
    function run() public view {
        console2.logAddress(OPAddressAliasHelper.applyL1ToL2Alias(0x7498e6e471f31e869f038D8DBffbDFdf650c3F95));
        //console2.logBytes4(type(IBaseMetadata).interfaceId);
        //console2.logBytes4(type(IPropertyIPFSMetadataRenderer).interfaceId);
    }
}
