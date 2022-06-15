// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";

import {OnChainMetadataRenderer} from "../../../src/token/metadata/OnChainMetadataRenderer.sol";
import {OnChainMetadataRendererStorage} from "../../../src/token/metadata/OnChainMetadataRendererStorage.sol";
import {Proxy} from "../../../src/upgrades/proxy/Proxy.sol";

contract MetadataRendererTest is DSTest {
    function test_SetupRenderer() public {
        OnChainMetadataRenderer impl = new OnChainMetadataRenderer();
        OnChainMetadataRendererStorage.ItemInfoStorage[] memory items = new OnChainMetadataRendererStorage.ItemInfoStorage[](7);
        // 100 prefix is for properties that are new
        items[0] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 100, dataType: 2, name: "Cloud", info: ""});
        items[1] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 100, dataType: 2, name: "CloudGray", info: ""});
        items[2] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 100, dataType: 2, name: "CloudLight", info: ""});
        items[3] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 100, dataType: 2, name: "Sun", info: ""});
        items[4] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 101, dataType: 2, name: "Grass", info: ""});
        items[5] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 101, dataType: 2, name: "Lava", info: ""});
        items[6] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 101, dataType: 2, name: "Water", info: ""});
        string[] memory names = new string[](2);
        names[0] = "Sky";
        names[1] = "Floor";
        bytes memory encoded = abi.encodeWithSelector(
            OnChainMetadataRenderer.initialize.selector,
            abi.encode(
                "Weather Slides",
                "Landscapes Combinations. One a day.",
                "ipfs://Qmew7TdyGnj6YRUjQR68sUJN3239MYXRD8uxowxF6rGK8j",
                "http://localhost:5000/render?"
            )
        );
        OnChainMetadataRenderer renderer = OnChainMetadataRenderer(address(new Proxy(address(impl), encoded)));
        // renderer.addProperties(names, items, abi.encode("QmQBJL2GS1SvpeXMhLHeCwenF9ZsdrTkJrtPxzczW3LXNT", ".png"));
        renderer.addProperties(names, items, abi.encode("Qmds9a4KdAyKqrBRMPyvDtoJc8QGMH45rgPnAGueSaCTYb", ".svg"));
        renderer.minted(1);
        assertEq("asdf", renderer.tokenURI(1));
    }
}
