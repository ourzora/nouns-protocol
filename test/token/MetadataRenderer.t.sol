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

    // function test_TokenURI() public {
    //     addProperties();

    //     vm.prank(foundersDAO);
    //     auction.unpause();

    //     string memory tokenURI = metadataRenderer.tokenURI(1);

    //     emit log_string(tokenURI);

    //     assertEq(
    //         tokenURI,
    //         "data:application/json;base64,eyJuYW1lIjogIk1vY2sgVG9rZW4gIzEiLCAiZGVzY3JpcHRpb24iOiAiVGhpcyBpcyBhIG1vY2sgdG9rZW4iLCAiaW1hZ2UiOiAiaHR0cDovL2xvY2FsaG9zdDo1MDAwL3JlbmRlcj9jb250cmFjdEFkZHJlc3M9MHg1Mjk3ZjIxYzcwNGVlZGRkYmIyYTNhZWQwMWMxN2Q0ZDFiZjA5NzhlJnRva2VuSWQ9MSZpbWFnZXM9aXBmcyUzYSUyZiUyZlFtZHM5YTRLZEF5S3FyQlJNUHl2RHRvSmM4UUdNSDQ1cmdQbkFHdWFhYUNUWWIlMmZTa3klMmZDbG91ZC5zdmcmaW1hZ2VzPWlwZnMlM2ElMmYlMmZRbWRzOWE0S2RBeUtxckJSTVB5dkR0b0pjOFFHTUg0NXJnUG5BR3VlU2FDVFliJTJmRmxvb3IlMmZMYXZhLnN2ZyIsICJwcm9wZXJ0aWVzIjogeyJTa3kiOiAiQ2xvdWQiLCJGbG9vciI6ICJMYXZhIn19"
    //     );
    // }

    function test_ContractURI() public {
        string memory contractURI = metadataRenderer.contractURI();

        assertEq(
            contractURI,
            "data:application/json;base64,eyJuYW1lIjogIk1vY2sgVG9rZW4iLCAiZGVzY3JpcHRpb24iOiAiVGhpcyBpcyBhIG1vY2sgdG9rZW4iLCAiaW1hZ2UiOiAiaXBmczovL1FtZXc3VGR5R25qNllSVWpRUjY4c1VKTjMyMzlNWVhSRDh1eG93eEY2ckdLOGoifQ=="
        );
    }
}
