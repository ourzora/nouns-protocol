// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { NounsBuilderTest } from "./utils/NounsBuilderTest.sol";

import { IManager, Manager } from "../src/manager/Manager.sol";
import { IToken, Token } from "../src/token/Token.sol";

import { MetadataRenderer } from "../src/token/metadata/MetadataRenderer.sol";
import { MetadataRendererTypesV1 } from "../src/token/metadata/types/MetadataRendererTypesV1.sol";

import { MetadataRendererTypesV1 } from "../src/token/metadata/types/MetadataRendererTypesV1.sol";

import { TokenTypesV1 } from "../src/token/types/TokenTypesV1.sol";

contract MetadataRendererTest is NounsBuilderTest, TokenTypesV1 {
    function setUp() public virtual override {
        super.setUp();
        deployMock();
    }

    function test_ContractURIInit() public {
        /**
 Result JSON: 
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

    function test_TokenURIInit() public {
        vm.prank(address(auction));

        string[] memory names = new string[](1);
        names[0] = "testing";
        MetadataRendererTypesV1.ItemParam[] memory items = new MetadataRendererTypesV1.ItemParam[](1);
        items[0].propertyId = 0;
        items[0].name = "testing";
        items[0].isNewProperty = true;
        MetadataRendererTypesV1.IPFSGroup memory ipfsGroup = MetadataRendererTypesV1.IPFSGroup({
            baseUri: "https://nouns.build/api/test",
            extension: ".json"
        });

        MetadataRenderer renderer = MetadataRenderer(token.metadataRenderer());
        vm.prank(founder);
        renderer.addProperties(names, items, ipfsGroup);

        vm.prank(address(auction));
        token.mint();

        /**
Result JSON:

{
  "name": "Mock Token #0",
  "description": "This is a mock token",
  "image": "http://localhost:5000/render?contractAddress=0x95681b5be82facb5c7236bcba304e52b5078a6a3&tokenId=0&images=https%3a%2f%2fnouns.build%2fapi%2ftesttesting%2ftesting.json",
  "properties": {
    "testing": "testing"
  }
}

*/
        assertEq(
            token.tokenURI(0),
            "data:application/json;base64,eyJuYW1lIjogIk1vY2sgVG9rZW4gIzAiLCJkZXNjcmlwdGlvbiI6ICJUaGlzIGlzIGEgbW9jayB0b2tlbiIsImltYWdlIjogImh0dHA6Ly9sb2NhbGhvc3Q6NTAwMC9yZW5kZXI/Y29udHJhY3RBZGRyZXNzPTB4OTU2ODFiNWJlODJmYWNiNWM3MjM2YmNiYTMwNGU1MmI1MDc4YTZhMyZ0b2tlbklkPTAmaW1hZ2VzPWh0dHBzJTNhJTJmJTJmbm91bnMuYnVpbGQlMmZhcGklMmZ0ZXN0dGVzdGluZyUyZnRlc3RpbmcuanNvbiIsInByb3BlcnRpZXMiOiB7InRlc3RpbmciOiAidGVzdGluZyJ9fQ=="
        );
    }
}
