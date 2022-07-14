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

        items[0] = IMetadataRenderer.ItemParam({isNewProperty: true, propertyId: 0, name: "Cloud"});
        items[1] = IMetadataRenderer.ItemParam({isNewProperty: true, propertyId: 0, name: "CloudGray"});
        items[2] = IMetadataRenderer.ItemParam({isNewProperty: true, propertyId: 0, name: "CloudLight"});
        items[3] = IMetadataRenderer.ItemParam({isNewProperty: true, propertyId: 0, name: "Sun"});
        items[4] = IMetadataRenderer.ItemParam({isNewProperty: true, propertyId: 1, name: "Grass"});
        items[5] = IMetadataRenderer.ItemParam({isNewProperty: true, propertyId: 1, name: "Lava"});
        items[6] = IMetadataRenderer.ItemParam({isNewProperty: true, propertyId: 1, name: "Water"});

        vm.prank(foundersDAO);
        metadataRenderer.addProperties(
            names,
            items,
            IMetadataRenderer.IPFSGroup({baseUri: "ipfs://Qmds9a4KdAyKqrBRMPyvDtoJc8QGMH45rgPnAGueSaCTYb/", extension: ".svg"})
        );

        string[] memory newNames = new string[](0);
        IMetadataRenderer.ItemParam[] memory newItems = new IMetadataRenderer.ItemParam[](1);
        newItems[0] = IMetadataRenderer.ItemParam({isNewProperty: false, propertyId: 0, name: "Cloud"}); 
        vm.prank(foundersDAO);
        metadataRenderer.addProperties(
            newNames,
            newItems,
            IMetadataRenderer.IPFSGroup({baseUri: "ipfs://Qmds9a4KdAyKqrBRMPyvDtoJc8QGMH45rgPnAGuaaaCTYb/", extension: ".svg"})
        );
    }

    function test_AddProperties() public {
        addProperties();

        assertEq(metadataRenderer.propertiesCount(), 2);
        assertEq(metadataRenderer.itemsCount(0), 5);
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
