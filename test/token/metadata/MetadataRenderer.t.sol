// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";

import {OnChainMetadataRenderer} from "../../../src/token/metadata/OnChainMetadataRenderer.sol";
import {OnChainMetadataRendererStorage} from "../../../src/token/metadata/OnChainMetadataRendererStorage.sol";

contract MetadataRendererTest is DSTest {
    function test_SetupRenderer() public {
        OnChainMetadataRenderer renderer = new OnChainMetadataRenderer();
        OnChainMetadataRendererStorage.ItemWithPropertyId[] memory items = new OnChainMetadataRendererStorage.ItemWithPropertyId[](4);
        items[0] = OnChainMetadataRendererStorage.ItemWithPropertyId({propertyId: 0, item: OnChainMetadataRendererStorage.Item({name: "Blue"})});
        items[1] = OnChainMetadataRendererStorage.ItemWithPropertyId({propertyId: 0, item: OnChainMetadataRendererStorage.Item({name: "Stormy"})});
        items[2] = OnChainMetadataRendererStorage.ItemWithPropertyId({propertyId: 1, item: OnChainMetadataRendererStorage.Item({name: "Grass"})});
        items[3] = OnChainMetadataRendererStorage.ItemWithPropertyId({propertyId: 1, item: OnChainMetadataRendererStorage.Item({name: "Lava"})});
        string[] memory names = new string[](2);
        names[0] = "Sky";
        names[1] = "Floor";
        renderer.initialize(
            abi.encode("Weather Slides", "Landscapes Combinations. One a day.", "ipfs://Qmew7TdyGnj6YRUjQR68sUJN3239MYXRD8uxowxF6rGK8j/")
        );
        renderer.addProperties(names, items);
        renderer.minted(1);
        assertEq("asdf", renderer.tokenURI(1));
    }
}
