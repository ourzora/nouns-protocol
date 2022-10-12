// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { NounsBuilderTest } from "./utils/NounsBuilderTest.sol";

import { Test } from "forge-std/Test.sol";
import { ClonesUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import { MetadataRenderer } from "../src/token/metadata/MetadataRenderer.sol";
import { MetadataRendererTypesV1 } from "../src/token/metadata/types/MetadataRendererTypesV1.sol";

contract MetadataRendererTest is NounsBuilderTest, MetadataRendererTypesV1 {
    function setUp() public virtual override {
        super.setUp();

        deployWithoutMetadata();
    }

    function testRevert_MustAddAtLeastOneItemWithProperty() public {
        string[] memory names = new string[](2);
        names[0] = "test";
        names[1] = "more test";

        ItemParam[] memory items = new ItemParam[](0);

        IPFSGroup memory ipfsGroup = IPFSGroup({ baseUri: "BASE_URI", extension: "EXTENSION" });

        vm.prank(founder);
        vm.expectRevert(abi.encodeWithSignature("ONE_PROPERTY_AND_ITEM_REQUIRED()"));
        metadataRenderer.addProperties(names, items, ipfsGroup);

        // Attempt to mint token #0
        vm.prank(address(token));
        bool response = metadataRenderer.onMinted(0);

        assertFalse(response);
    }

    function testRevert_MustAddAtLeastOnePropertyWithItem() public {
        string[] memory names = new string[](0);

        ItemParam[] memory items = new ItemParam[](2);
        items[0] = ItemParam({ propertyId: 0, name: "failure", isNewProperty: false });
        items[1] = ItemParam({ propertyId: 0, name: "failure", isNewProperty: true });

        IPFSGroup memory ipfsGroup = IPFSGroup({ baseUri: "BASE_URI", extension: "EXTENSION" });

        vm.prank(founder);
        vm.expectRevert(abi.encodeWithSignature("ONE_PROPERTY_AND_ITEM_REQUIRED()"));
        metadataRenderer.addProperties(names, items, ipfsGroup);

        vm.prank(address(token));
        bool response = metadataRenderer.onMinted(0);
        assertFalse(response);
    }

    function testRevert_MustAddItemForExistingProperty() public {
        string[] memory names = new string[](1);
        names[0] = "testing";

        ItemParam[] memory items = new ItemParam[](2);
        items[0] = ItemParam({ propertyId: 0, name: "failure", isNewProperty: true });
        items[1] = ItemParam({ propertyId: 2, name: "failure", isNewProperty: false });

        IPFSGroup memory ipfsGroup = IPFSGroup({ baseUri: "BASE_URI", extension: "EXTENSION" });

        vm.prank(founder);
        vm.expectRevert(abi.encodeWithSignature("INVALID_PROPERTY_SELECTED(uint256)", 2));
        metadataRenderer.addProperties(names, items, ipfsGroup);

        // 0th token minted
        vm.prank(address(token));
        bool response = metadataRenderer.onMinted(0);
        assertFalse(response);
    }

    function test_AddNewPropertyWithItems() public {
        string[] memory names = new string[](1);
        names[0] = "testing";

        ItemParam[] memory items = new ItemParam[](2);
        items[0] = ItemParam({ propertyId: 0, name: "failure1", isNewProperty: true });
        items[1] = ItemParam({ propertyId: 0, name: "failure2", isNewProperty: true });

        IPFSGroup memory ipfsGroup = IPFSGroup({ baseUri: "BASE_URI", extension: "EXTENSION" });

        vm.prank(founder);
        metadataRenderer.addProperties(names, items, ipfsGroup);

        vm.prank(address(token));
        bool response = metadataRenderer.onMinted(0);
        assertTrue(response);
    }
}
