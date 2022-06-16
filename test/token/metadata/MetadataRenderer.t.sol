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
        items[0] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 100, dataType: 0, name: "Cloud", info: ""});
        items[1] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 100, dataType: 0, name: "CloudGray", info: ""});
        items[2] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 100, dataType: 0, name: "CloudLight", info: ""});
        items[3] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 100, dataType: 0, name: "Sun", info: ""});
        items[4] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 101, dataType: 0, name: "Grass", info: ""});
        items[5] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 101, dataType: 0, name: "Lava", info: ""});
        items[6] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 101, dataType: 0, name: "Water", info: ""});
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
    function test_SetupManyProperties() public {
       OnChainMetadataRenderer impl = new OnChainMetadataRenderer();
        OnChainMetadataRendererStorage.ItemInfoStorage[] memory items = new OnChainMetadataRendererStorage.ItemInfoStorage[](22);
        // 100 prefix is for properties that are new
        items[0] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 100, dataType: 0, name: "Cloud", info: ""});
        items[1] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 100, dataType: 0, name: "CloudGray", info: ""});
        items[2] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 100, dataType: 0, name: "CloudLight", info: ""});
        items[3] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 100, dataType: 0, name: "Sun", info: ""});
        items[4] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 101, dataType: 0, name: "Grass", info: ""});
        items[5] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 101, dataType: 0, name: "Lava", info: ""});
        items[6] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 101, dataType: 0, name: "Water", info: ""});
        items[7] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 100, dataType: 0, name: "CloudLight", info: ""});
        items[8] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 100, dataType: 0, name: "Sun", info: ""});
        items[9] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 101, dataType: 0, name: "Grass", info: ""});
        items[10] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 101, dataType: 0, name: "Lava", info: ""});
        items[11] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 101, dataType: 0, name: "Water", info: ""});
        items[12] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 100, dataType: 0, name: "CloudLight", info: ""});
        items[13] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 100, dataType: 0, name: "Sun", info: ""});
        items[14] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 101, dataType: 0, name: "Grass", info: ""});
        items[15] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 101, dataType: 0, name: "Lava", info: ""});
        items[16] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 101, dataType: 0, name: "Water", info: ""});
        items[17] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 101, dataType: 0, name: "Water", info: ""});
        items[18] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 101, dataType: 0, name: "Water", info: ""});
        items[19] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 101, dataType: 0, name: "Water", info: ""});
        items[20] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 101, dataType: 0, name: "Water", info: ""});
        items[21] = OnChainMetadataRendererStorage.ItemInfoStorage({propertyId: 101, dataType: 0, name: "Water", info: ""});
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
