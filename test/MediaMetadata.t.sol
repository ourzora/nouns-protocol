// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { NounsBuilderTest } from "./utils/NounsBuilderTest.sol";
import { MediaMetadata } from "../src/metadata/media/MediaMetadata.sol";
import { MediaMetadataTypesV1 } from "../src/metadata/media/types/MediaMetadataTypesV1.sol";

import { Base64URIDecoder } from "./utils/Base64URIDecoder.sol";
import "forge-std/console2.sol";

contract MediaMetadataTest is NounsBuilderTest, MediaMetadataTypesV1 {
    MediaMetadata mediaMetadata;

    function setUp() public virtual override {
        super.setUp();

        deployWithoutMetadata();

        address mediaMetadataImpl = address(new MediaMetadata(address(manager)));

        vm.startPrank(founder);
        address mediaAddress = manager.setMetadataRenderer(address(token), mediaMetadataImpl, implData[manager.IMPLEMENTATION_TYPE_METADATA()]);
        vm.stopPrank();

        mediaMetadata = MediaMetadata(mediaAddress);
    }

    function testRevert_MustAddAtLeastOneMediaItem() public {
        MediaItem[] memory items = new MediaItem[](0);

        vm.prank(founder);
        vm.expectRevert(abi.encodeWithSignature("ONE_MEDIA_ITEM_REQUIRED()"));
        mediaMetadata.addMediaItems(items);

        // Attempt to mint token #0
        vm.prank(address(token));
        bool response = mediaMetadata.onMinted(0);

        assertFalse(response);
    }

    function test_AddNewMediaItems() public {
        MediaItem[] memory items = new MediaItem[](1);
        items[0] = MediaItem({ imageURI: "img1", animationURI: "ani1" });

        vm.prank(founder);
        mediaMetadata.addMediaItems(items);

        vm.prank(address(token));
        bool response = mediaMetadata.onMinted(0);
        assertTrue(response);
    }

    function test_deleteAndRecreateMediaItems() public {
        MediaItem[] memory items = new MediaItem[](2);
        items[0] = MediaItem({ imageURI: "img1", animationURI: "ani1" });
        items[1] = MediaItem({ imageURI: "img2", animationURI: "ani2" });

        vm.prank(founder);
        mediaMetadata.addMediaItems(items);

        vm.prank(address(token));
        bool response = mediaMetadata.onMinted(0);
        assertTrue(response);

        items[0] = MediaItem({ imageURI: "upsertImg1", animationURI: "upsertAni1" });
        items[1] = MediaItem({ imageURI: "upsertImg2", animationURI: "upsertAni2" });

        vm.prank(founder);
        mediaMetadata.deleteAndRecreateMediaItems(items);

        vm.prank(address(token));
        response = mediaMetadata.onMinted(0);
        assertTrue(response);
    }

    function test_MintPastItemCount() public {
        MediaItem[] memory items = new MediaItem[](2);
        items[0] = MediaItem({ imageURI: "img1", animationURI: "ani1" });
        items[1] = MediaItem({ imageURI: "img2", animationURI: "ani2" });

        vm.prank(founder);
        mediaMetadata.addMediaItems(items);

        vm.prank(address(token));
        bool response = mediaMetadata.onMinted(3);
        assertFalse(response);
    }

    function test_MintPastItemCountAndContinue() public {
        MediaItem[] memory items = new MediaItem[](2);
        items[0] = MediaItem({ imageURI: "img1", animationURI: "ani1" });
        items[1] = MediaItem({ imageURI: "img2", animationURI: "ani2" });

        vm.prank(founder);
        mediaMetadata.addMediaItems(items);

        vm.prank(address(token));
        bool response = mediaMetadata.onMinted(3);
        assertFalse(response);

        MediaItem[] memory newItems = new MediaItem[](2);
        newItems[0] = MediaItem({ imageURI: "img3", animationURI: "ani3" });
        newItems[1] = MediaItem({ imageURI: "img4", animationURI: "ani4" });

        vm.prank(founder);
        mediaMetadata.addMediaItems(newItems);

        vm.prank(address(token));
        response = mediaMetadata.onMinted(3);
        assertTrue(response);
    }

    function test_UpdateMetadata() public {
        assertEq(mediaMetadata.description(), "This is a mock token");
        assertEq(mediaMetadata.projectURI(), "https://nouns.build");

        vm.startPrank(founder);
        mediaMetadata.updateDescription("new description");
        mediaMetadata.updateProjectURI("https://nouns.build/about");
        vm.stopPrank();

        assertEq(mediaMetadata.description(), "new description");
        assertEq(mediaMetadata.projectURI(), "https://nouns.build/about");
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

    function test_TokenURI() public {
        MediaItem[] memory items = new MediaItem[](3);
        items[0] = MediaItem({ imageURI: "img0", animationURI: "ani0" });
        items[1] = MediaItem({ imageURI: "img1", animationURI: "ani1" });
        items[2] = MediaItem({ imageURI: "img2", animationURI: "ani2" });

        vm.prank(founder);
        mediaMetadata.addMediaItems(items);

        vm.prank(address(auction));
        token.mint();

        /**
        TokenURI Result Pretty JSON:
        {
            "name": "Mock Token #0",
            "description": "This is a mock token",
            "image": "img0",
            "animation": "ani0"
        }
         */

        string memory json = Base64URIDecoder.decodeURI("data:application/json;base64,", token.tokenURI(0));

        assertEq(json, '{"name": "Mock Token #0","description": "This is a mock token","image": "img0","animation_url": "ani0"}');
    }
}
