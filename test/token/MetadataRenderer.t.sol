// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {IMetadataRenderer} from "../../src/token/metadata/MetadataRenderer.sol";

import {NounsBuilderTest} from "../utils/NounsBuilderTest.sol";

contract MetadataRendererTest is NounsBuilderTest {
    function setUp() public virtual override {
        super.setUp();

        deploy();
    }

    function addProperties() public {
        string[] memory names = new string[](2);

        names[0] = "Sky";
        names[1] = "Floor";

        IMetadataRenderer.ItemParam[] memory items = new IMetadataRenderer.ItemParam[](7);

        items[0] = IMetadataRenderer.ItemParam({propertyId: 100, dataType: 0, name: "Cloud", info: ""});
        items[1] = IMetadataRenderer.ItemParam({propertyId: 100, dataType: 0, name: "CloudGray", info: ""});
        items[2] = IMetadataRenderer.ItemParam({propertyId: 100, dataType: 0, name: "CloudLight", info: ""});
        items[3] = IMetadataRenderer.ItemParam({propertyId: 100, dataType: 0, name: "Sun", info: ""});
        items[4] = IMetadataRenderer.ItemParam({propertyId: 101, dataType: 0, name: "Grass", info: ""});
        items[5] = IMetadataRenderer.ItemParam({propertyId: 101, dataType: 0, name: "Lava", info: ""});
        items[6] = IMetadataRenderer.ItemParam({propertyId: 101, dataType: 0, name: "Water", info: ""});

        bytes memory data = abi.encode("Qmds9a4KdAyKqrBRMPyvDtoJc8QGMH45rgPnAGueSaCTYb", ".svg");

        vm.prank(foundersDAO);
        metadataRenderer.addProperties(names, items, data);
    }

    function test_AddProperties() public {
        addProperties();

        assertEq(metadataRenderer.propertiesCount(), 2);
        assertEq(metadataRenderer.itemsCount(0), 4);
        assertEq(metadataRenderer.itemsCount(1), 3);
    }

    function test_TokenURI() public {
        addProperties();

        vm.prank(foundersDAO);
        auction.unpause();

        string memory tokenURI = metadataRenderer.tokenURI(1);

        emit log_string(tokenURI);
    }

    function test_ContractURI() public {
        string memory contractURI = metadataRenderer.contractURI();

        emit log_string(contractURI);
    }
}
