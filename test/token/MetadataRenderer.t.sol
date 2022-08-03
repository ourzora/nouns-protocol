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

    function test_UpdateDescription() public {
        vm.expectRevert("Ownable: caller is not the owner");
        metadataRenderer.updateDescription("new desc");

        vm.prank(foundersDAO);
        metadataRenderer.updateDescription("new desc");
        assertEq(metadataRenderer.getDescription(), "new desc");
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

        assertEq(
            tokenURI,
            '{"name": "Mock Token #1", "description": "This is a mock token", "image": "http://localhost:5000/render?contractAddress=0xff1f22fa4aba99150fb4d9fc8dd449d6e3b8f2db&tokenId=1&images=ipfs%3a%2f%2fQmds9a4KdAyKqrBRMPyvDtoJc8QGMH45rgPnAGuaaaCTYb%2fSky%2fCloud.svg&images=ipfs%3a%2f%2fQmds9a4KdAyKqrBRMPyvDtoJc8QGMH45rgPnAGueSaCTYb%2fFloor%2fLava.svg", "properties": {"Sky": "Cloud","Floor": "Lava"}}'
        );
    }

    function test_ContractURI() public {
        string memory contractURI = metadataRenderer.contractURI();

        assertEq(
            contractURI,
            '{"name": "Mock Token", "description": "This is a mock token", "image": "ipfs://Qmew7TdyGnj6YRUjQR68sUJN3239MYXRD8uxowxF6rGK8j"}'
        );
    }
}
