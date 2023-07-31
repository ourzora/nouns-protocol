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
        MediaItem[] memory items = new MediaItem[](2);
        items[0] = MediaItem({ imageURI: "img1", animationURI: "ani1" });
        items[1] = MediaItem({ imageURI: "img2", animationURI: "ani2" });

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
}
