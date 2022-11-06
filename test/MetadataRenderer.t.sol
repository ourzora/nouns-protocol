// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { NounsBuilderTest } from "./utils/NounsBuilderTest.sol";
import { MetadataRendererTypesV1 } from "../src/token/metadata/types/MetadataRendererTypesV1.sol";
import { MetadataRendererTypesV2 } from "../src/token/metadata/types/MetadataRendererTypesV2.sol";

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
            base64 -d
            eyJuYW1lIjogIk1vY2sgVG9rZW4iLCJkZXNjcmlwdGlvbiI6ICJUaGlzIGlzIGEgbW9jayB0b2tlbiIsImltYWdlIjogImlwZnM6Ly9RbWV3N1RkeUduajZZUlVqUVI2OHNVSk4zMjM5TVlYUkQ4dXhvd3hGNnJHSzhqIiwiZXh0ZXJuYWxfdXJsIjogImh0dHBzOi8vbm91bnMuYnVpbGQifQ==
            {"name": "Mock Token","description": "This is a mock token","image": "ipfs://Qmew7TdyGnj6YRUjQR68sUJN3239MYXRD8uxowxF6rGK8j","external_url": "https://nouns.build"}
        */
        assertEq(
            token.contractURI(),
            "data:application/json;base64,eyJuYW1lIjogIk1vY2sgVG9rZW4iLCJkZXNjcmlwdGlvbiI6ICJUaGlzIGlzIGEgbW9jayB0b2tlbiIsImltYWdlIjogImlwZnM6Ly9RbWV3N1RkeUduajZZUlVqUVI2OHNVSk4zMjM5TVlYUkQ4dXhvd3hGNnJHSzhqIiwiZXh0ZXJuYWxfdXJsIjogImh0dHBzOi8vbm91bnMuYnVpbGQifQ=="
        );
    }

    function test_UpdateMetadata() public {
        assertEq(metadataRenderer.description(), "This is a mock token");
        assertEq(metadataRenderer.projectURI(), "https://nouns.build");

        vm.startPrank(founder);
        metadataRenderer.updateDescription("new description");
        metadataRenderer.updateProjectURI("https://nouns.build/about");
        vm.stopPrank();

        assertEq(metadataRenderer.description(), "new description");
        assertEq(metadataRenderer.projectURI(), "https://nouns.build/about");

    }

    function test_AddAdditionalProperties() public {
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


        MetadataRendererTypesV2.AdditionalTokenProperty[] memory additionalTokenProperties = new MetadataRendererTypesV2.AdditionalTokenProperty[](2);
        additionalTokenProperties[0] = MetadataRendererTypesV2.AdditionalTokenProperty({
            key: "testing",
            value: "HELLO",
            quote: true
        });
        additionalTokenProperties[1] = MetadataRendererTypesV2.AdditionalTokenProperty({
            key: "participationAgreement",
            value: "This is a JSON quoted participation agreement.",
            quote: true
        });
        vm.prank(founder);
        metadataRenderer.setAdditionalTokenProperties(additionalTokenProperties);

        /**
            Token URI additional properties result:

            {
                "name": "Mock Token #0",
                "description": "This is a mock token",
                "image": "http://localhost:5000/render?contractAddress=0xa37a694f029389d5167808761c1b62fcef775288&tokenId=0&images=https%3a%2f%2fnouns.build%2fapi%2ftest%2fmock-property%2fmock-item.json",
                "properties": {
                    "mock-property": "mock-item"
                },
                "testing": "HELLO",
                "participationAgreement": "This is a JSON quoted participation agreement."
            }
        
        */

        assertEq(
            token.tokenURI(0),
            "data:application/json;base64,eyJuYW1lIjogIk1vY2sgVG9rZW4gIzAiLCJkZXNjcmlwdGlvbiI6ICJUaGlzIGlzIGEgbW9jayB0b2tlbiIsImltYWdlIjogImh0dHA6Ly9sb2NhbGhvc3Q6NTAwMC9yZW5kZXI/Y29udHJhY3RBZGRyZXNzPTB4YTM3YTY5NGYwMjkzODlkNTE2NzgwODc2MWMxYjYyZmNlZjc3NTI4OCZ0b2tlbklkPTAmaW1hZ2VzPWh0dHBzJTNhJTJmJTJmbm91bnMuYnVpbGQlMmZhcGklMmZ0ZXN0JTJmbW9jay1wcm9wZXJ0eSUyZm1vY2staXRlbS5qc29uIiwicHJvcGVydGllcyI6IHsibW9jay1wcm9wZXJ0eSI6ICJtb2NrLWl0ZW0ifSwidGVzdGluZyI6ICJIRUxMTyIsInBhcnRpY2lwYXRpb25BZ3JlZW1lbnQiOiAiVGhpcyBpcyBhIEpTT04gcXVvdGVkIHBhcnRpY2lwYXRpb24gYWdyZWVtZW50LiJ9"
        );
    }

    function test_AddAndClearAdditionalProperties() public {
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


        MetadataRendererTypesV2.AdditionalTokenProperty[] memory additionalTokenProperties = new MetadataRendererTypesV2.AdditionalTokenProperty[](2);
        additionalTokenProperties[0] = MetadataRendererTypesV2.AdditionalTokenProperty({
            key: "testing",
            value: "HELLO",
            quote: true
        });
        additionalTokenProperties[1] = MetadataRendererTypesV2.AdditionalTokenProperty({
            key: "participationAgreement",
            value: "This is a JSON quoted participation agreement.",
            quote: true
        });
        vm.prank(founder);
        metadataRenderer.setAdditionalTokenProperties(additionalTokenProperties);

        string memory withAdditionalTokenProperties = token.tokenURI(0);

        MetadataRendererTypesV2.AdditionalTokenProperty[] memory clearedTokenProperties = new MetadataRendererTypesV2.AdditionalTokenProperty[](0);
        vm.prank(founder);
        metadataRenderer.setAdditionalTokenProperties(clearedTokenProperties);

        // Ensure no additional properties are sent
        assertEq(
            token.tokenURI(0),
            "data:application/json;base64,eyJuYW1lIjogIk1vY2sgVG9rZW4gIzAiLCJkZXNjcmlwdGlvbiI6ICJUaGlzIGlzIGEgbW9jayB0b2tlbiIsImltYWdlIjogImh0dHA6Ly9sb2NhbGhvc3Q6NTAwMC9yZW5kZXI/Y29udHJhY3RBZGRyZXNzPTB4YTM3YTY5NGYwMjkzODlkNTE2NzgwODc2MWMxYjYyZmNlZjc3NTI4OCZ0b2tlbklkPTAmaW1hZ2VzPWh0dHBzJTNhJTJmJTJmbm91bnMuYnVpbGQlMmZhcGklMmZ0ZXN0JTJmbW9jay1wcm9wZXJ0eSUyZm1vY2staXRlbS5qc29uIiwicHJvcGVydGllcyI6IHsibW9jay1wcm9wZXJ0eSI6ICJtb2NrLWl0ZW0ifX0="
        );

        assertTrue(
            keccak256(bytes(withAdditionalTokenProperties)) != keccak256(bytes(token.tokenURI(0)))
        );
    }


    function test_UnicodeProperties() public {
        string[] memory names = new string[](1);
        names[0] = unicode"mock-⌐ ◨-◨-.∆property";

        ItemParam[] memory items = new ItemParam[](1);
        items[0].propertyId = 0;
        items[0].name = unicode' ⌐◨-◨ ';
        items[0].isNewProperty = true;

        IPFSGroup memory ipfsGroup = IPFSGroup({ baseUri: "https://nouns.build/api/test/", extension: ".json" });

        vm.prank(founder);
        metadataRenderer.addProperties(names, items, ipfsGroup);

        vm.prank(address(auction));
        token.mint();


        MetadataRendererTypesV2.AdditionalTokenProperty[] memory additionalTokenProperties = new MetadataRendererTypesV2.AdditionalTokenProperty[](2);
        additionalTokenProperties[0] = MetadataRendererTypesV2.AdditionalTokenProperty({
            key: "testing",
            value: "HELLO",
            quote: true
        });
        additionalTokenProperties[1] = MetadataRendererTypesV2.AdditionalTokenProperty({
            key: "participationAgreement",
            value: "This is a JSON quoted participation agreement.",
            quote: true
        });
        vm.prank(founder);
        metadataRenderer.setAdditionalTokenProperties(additionalTokenProperties);

        string memory withAdditionalTokenProperties = token.tokenURI(0);

        MetadataRendererTypesV2.AdditionalTokenProperty[] memory clearedTokenProperties = new MetadataRendererTypesV2.AdditionalTokenProperty[](0);
        vm.prank(founder);
        metadataRenderer.setAdditionalTokenProperties(clearedTokenProperties);

        // Ensure no additional properties are sent

        // result: {"name": "Mock Token #0","description": "This is a mock token","image": "http://localhost:5000/render?contractAddress=0xa37a694f029389d5167808761c1b62fcef775288&tokenId=0&images=https%3a%2f%2fnouns.build%2fapi%2ftest%2fmock-%e2%8c%90%20%e2%97%a8-%e2%97%a8-.%e2%88%86property%2f%20%e2%8c%90%e2%97%a8-%e2%97%a8%20.json","properties": {"mock-⌐ ◨-◨-.∆property": " ⌐◨-◨ "}}
        // JSON parse: 
        // {
        //   name: 'Mock Token #0',
        //   description: 'This is a mock token',
        //   image: 'http://localhost:5000/render?contractAddress=0xa37a694f029389d5167808761c1b62fcef775288&tokenId=0&images=https%3a%2f%2fnouns.build%2fapi%2ftest%2fmock-%e2%8c%90%20%e2%97%a8-%e2%97%a8-.%e2%88%86property%2f%20%e2%8c%90%e2%97%a8-%e2%97%a8%20.json',
        //   properties: { 'mock-⌐ ◨-◨-.∆property': ' ⌐◨-◨ ' }
        // }
        // > decodeURIComponent('https%3a%2f%2fnouns.build%2fapi%2ftest%2fmock-%e2%8c%90%20%e2%97%a8-%e2%97%a8-.%e2%88%86property%2f%20%e2%8c%90%e2%97%a8-%e2%97%a8%20.json')
        // 'https://nouns.build/api/test/mock-⌐ ◨-◨-.∆property/ ⌐◨-◨ .json'

        assertEq(
            token.tokenURI(0),
            "data:application/json;base64,eyJuYW1lIjogIk1vY2sgVG9rZW4gIzAiLCJkZXNjcmlwdGlvbiI6ICJUaGlzIGlzIGEgbW9jayB0b2tlbiIsImltYWdlIjogImh0dHA6Ly9sb2NhbGhvc3Q6NTAwMC9yZW5kZXI/Y29udHJhY3RBZGRyZXNzPTB4YTM3YTY5NGYwMjkzODlkNTE2NzgwODc2MWMxYjYyZmNlZjc3NTI4OCZ0b2tlbklkPTAmaW1hZ2VzPWh0dHBzJTNhJTJmJTJmbm91bnMuYnVpbGQlMmZhcGklMmZ0ZXN0JTJmbW9jay0lZTIlOGMlOTAlMjAlZTIlOTclYTgtJWUyJTk3JWE4LS4lZTIlODglODZwcm9wZXJ0eSUyZiUyMCVlMiU4YyU5MCVlMiU5NyVhOC0lZTIlOTclYTglMjAuanNvbiIsInByb3BlcnRpZXMiOiB7Im1vY2st4oyQIOKXqC3il6gtLuKIhnByb3BlcnR5IjogIiDijJDil6gt4peoICJ9fQ=="
        );

        assertTrue(
            keccak256(bytes(withAdditionalTokenProperties)) != keccak256(bytes(token.tokenURI(0)))
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
            "image": "http://localhost:5000/render?contractAddress=0xa37a694f029389d5167808761c1b62fcef775288&tokenId=0&images=https%3a%2f%2fnouns.build%2fapi%2ftest%2fmock-property%2fmock-item.json",
            "properties": {
                "mock-property": "mock-item"
            }
        }
         */

        assertEq(
            token.tokenURI(0),
            "data:application/json;base64,eyJuYW1lIjogIk1vY2sgVG9rZW4gIzAiLCJkZXNjcmlwdGlvbiI6ICJUaGlzIGlzIGEgbW9jayB0b2tlbiIsImltYWdlIjogImh0dHA6Ly9sb2NhbGhvc3Q6NTAwMC9yZW5kZXI/Y29udHJhY3RBZGRyZXNzPTB4YTM3YTY5NGYwMjkzODlkNTE2NzgwODc2MWMxYjYyZmNlZjc3NTI4OCZ0b2tlbklkPTAmaW1hZ2VzPWh0dHBzJTNhJTJmJTJmbm91bnMuYnVpbGQlMmZhcGklMmZ0ZXN0JTJmbW9jay1wcm9wZXJ0eSUyZm1vY2staXRlbS5qc29uIiwicHJvcGVydGllcyI6IHsibW9jay1wcm9wZXJ0eSI6ICJtb2NrLWl0ZW0ifX0="
        );
    }
}
