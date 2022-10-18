// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { NounsBuilderTest } from "./utils/NounsBuilderTest.sol";
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

    function testRevert_CannotExceedMaxProperties() public {
        string[] memory names = new string[](16);

        MetadataRendererTypesV1.ItemParam[] memory items = new MetadataRendererTypesV1.ItemParam[](16);

        for (uint256 j; j < 16; j++) {
            names[j] = "aaa"; // Add random properties

            items[j].name = "aaa"; // Add random items
            items[j].propertyId = uint16(j); // Make sure all properties have items
            items[j].isNewProperty = true;
        }

        MetadataRendererTypesV1.IPFSGroup memory group = MetadataRendererTypesV1.IPFSGroup("aaa", "aaa");

        vm.prank(founder);
        vm.expectRevert(abi.encodeWithSignature("TOO_MANY_PROPERTIES()"));
        metadataRenderer.addProperties(names, items, group);
    }

    function test_ContractURI() public {
        /**
        ContractURI Result Pretty JSON: 
        {
            "name": "Mock Token",
            "description": "This is a mock token",
            "image": "ipfs://Qmew7TdyGnj6YRUjQR68sUJN3239MYXRD8uxowxF6rGK8j"
        } 
        */
        assertEq(
            token.contractURI(),
            "data:application/json;base64,eyJuYW1lIjogIk1vY2sgVG9rZW4iLCJkZXNjcmlwdGlvbiI6ICJUaGlzIGlzIGEgbW9jayB0b2tlbiIsImltYWdlIjogImlwZnM6Ly9RbWV3N1RkeUduajZZUlVqUVI2OHNVSk4zMjM5TVlYUkQ4dXhvd3hGNnJHSzhqIn0="
        );
    }

    function test_TokenURI() public {
        string[] memory names = new string[](1);
        names[0] = "mock-property";

        ItemParam[] memory items = new ItemParam[](1);
        items[0].propertyId = 0;
        items[0].name = "mock-item";
        items[0].isNewProperty = true;

        IPFSGroup memory ipfsGroup = IPFSGroup({ baseUri: "https://nouns.build/api/test/", extension: ".json" });

        vm.prank(founder);
        metadataRenderer.addProperties(names, items, ipfsGroup);

        vm.prank(address(auction));
        token.mint();

        /**
        TokenURI Result Pretty JSON:
        {
            "name": "Mock Token #0",
            "description": "This is a mock token",
            "image": "http://localhost:5000/render?contractAddress=0xbe40948f30dea3de73b529044ef16e79ac8daf16&tokenId=0&images=https%3a%2f%2fnouns.build%2fapi%2ftest%2fmock-property%2fmock-item.json",
            "properties": {
                "mock-property": "mock-item"
            }
        }
         */

        assertEq(
            token.tokenURI(0),
            "data:application/json;base64,eyJuYW1lIjogIk1vY2sgVG9rZW4gIzAiLCJkZXNjcmlwdGlvbiI6ICJUaGlzIGlzIGEgbW9jayB0b2tlbiIsImltYWdlIjogImh0dHA6Ly9sb2NhbGhvc3Q6NTAwMC9yZW5kZXI/Y29udHJhY3RBZGRyZXNzPTB4ODAzYmI1YzdhZGIwYmM0YzU1MDU3YmU1ZWZmNGIyZWU4NTc1MjBiNSZ0b2tlbklkPTAmaW1hZ2VzPWh0dHBzJTNhJTJmJTJmbm91bnMuYnVpbGQlMmZhcGklMmZ0ZXN0JTJmbW9jay1wcm9wZXJ0eSUyZm1vY2staXRlbS5qc29uIiwicHJvcGVydGllcyI6IHsibW9jay1wcm9wZXJ0eSI6ICJtb2NrLWl0ZW0ifX0="
        );
    }
}
