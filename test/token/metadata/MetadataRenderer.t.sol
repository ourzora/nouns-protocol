// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Test } from "forge-std/Test.sol";
import { ClonesUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import { MetadataRenderer } from "../../../token/metadata/MetadataRenderer.sol";
import { MetadataRendererTypesV1 } from "../../../token/metadata/types/MetadataRendererTypesV1.sol";

contract MetadataRendererTest is Test {
    address token = address(0x12);
    address founder = address(0x23);
    address treasury = address(0x43);
    address manager = address(0x39);
    MetadataRenderer instance;

    function setUp() public {
        vm.label(token, "token");
        vm.label(founder, "founder");
        vm.label(treasury, "treasury");
        vm.label(manager, "manager");

        MetadataRenderer renderer = new MetadataRenderer(manager);
        instance = MetadataRenderer(ClonesUpgradeable.clone(address(renderer)));

        vm.prank(manager);
        instance.initialize(abi.encode("name", "", "description", "CONTRACT_IMAGE", "RENDERER_BASE"), token, founder, treasury);
    }

    function testMetadataSetupFailsNoItemData() public {
        string[] memory names = new string[](2);
        names[0] = "test";
        names[1] = "more test";
        MetadataRendererTypesV1.ItemParam[] memory items = new MetadataRendererTypesV1.ItemParam[](0);
        MetadataRendererTypesV1.IPFSGroup memory ipfsGroup = MetadataRendererTypesV1.IPFSGroup({ baseUri: "BASE_URI", extension: "EXTENSION" });
        vm.startPrank(founder);
        vm.expectRevert(MetadataRenderer.AtLeastOneItemAndPropertyRequired.selector);
        instance.addProperties(names, items, ipfsGroup);
        vm.stopPrank();
        // 0th token minted
        vm.prank(token);
        bool response = instance.onMinted(0);
        assertFalse(response);
    }

    function testMetadataSetupFailsNoNamesData() public {
        string[] memory names = new string[](0);
        MetadataRendererTypesV1.ItemParam[] memory items = new MetadataRendererTypesV1.ItemParam[](2);
        MetadataRendererTypesV1.IPFSGroup memory ipfsGroup = MetadataRendererTypesV1.IPFSGroup({ baseUri: "BASE_URI", extension: "EXTENSION" });
        items[0] = MetadataRendererTypesV1.ItemParam({
            propertyId: 0,
            name: "failure",
            isNewProperty: false
        });
        items[1] = MetadataRendererTypesV1.ItemParam({
            propertyId: 0,
            name: "failure",
            isNewProperty: true
        });
        vm.startPrank(founder);
        vm.expectRevert(MetadataRenderer.AtLeastOneItemAndPropertyRequired.selector);
        instance.addProperties(names, items, ipfsGroup);
        vm.stopPrank();
        vm.prank(token);
        // 0th token minted
        bool response = instance.onMinted(0);
        assertFalse(response);
    }

    function testInvalidPropertyReference() public {
        string[] memory names = new string[](1);
        names[0] = "testing";
        MetadataRendererTypesV1.ItemParam[] memory items = new MetadataRendererTypesV1.ItemParam[](2);
        MetadataRendererTypesV1.IPFSGroup memory ipfsGroup = MetadataRendererTypesV1.IPFSGroup({ baseUri: "BASE_URI", extension: "EXTENSION" });
        items[0] = MetadataRendererTypesV1.ItemParam({
            propertyId: 0,
            name: "failure",
            isNewProperty: true
        });
        items[1] = MetadataRendererTypesV1.ItemParam({
            propertyId: 2,
            name: "failure",
            isNewProperty: false
        });
        vm.startPrank(founder);
        vm.expectRevert(abi.encodeWithSelector(MetadataRenderer.InvalidPropertySelected.selector, 2));
        instance.addProperties(names, items, ipfsGroup);
        vm.stopPrank();
        vm.prank(token);
        // 0th token minted
        bool response = instance.onMinted(0);
        assertFalse(response);
    }

    function testNewPropertySetupSuccess() public {
        string[] memory names = new string[](1);
        names[0] = "testing";
        MetadataRendererTypesV1.ItemParam[] memory items = new MetadataRendererTypesV1.ItemParam[](2);
        MetadataRendererTypesV1.IPFSGroup memory ipfsGroup = MetadataRendererTypesV1.IPFSGroup({ baseUri: "BASE_URI", extension: "EXTENSION" });
        items[0] = MetadataRendererTypesV1.ItemParam({
            propertyId: 0,
            name: "failure1",
            isNewProperty: true
        });
        items[1] = MetadataRendererTypesV1.ItemParam({
            propertyId: 0,
            name: "failure2",
            isNewProperty: true
        });
        vm.startPrank(founder);
        instance.addProperties(names, items, ipfsGroup);
        vm.stopPrank();
        vm.prank(token);
        // 0th token minted
        bool response = instance.onMinted(0);
        assertTrue(response);
    }

}
