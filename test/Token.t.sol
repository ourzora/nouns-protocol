// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { NounsBuilderTest } from "./utils/NounsBuilderTest.sol";

import { IManager, Manager } from "../src/manager/Manager.sol";
import { IToken, Token } from "../src/token/Token.sol";

import { MetadataRendererTypesV1 } from "../src/token/metadata/types/MetadataRendererTypesV1.sol";

import { TokenTypesV1 } from "../src/token/types/TokenTypesV1.sol";

contract TokenTest is NounsBuilderTest, TokenTypesV1 {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_MockTokenInit() public {
        deployMock();

        assertEq(token.name(), "Mock Token");
        assertEq(token.symbol(), "MOCK");
        assertEq(token.auction(), address(auction));
        assertEq(token.owner(), founder);
        assertEq(token.metadataRenderer(), address(metadataRenderer));
        assertEq(token.totalSupply(), 0);
    }

    function test_MockFounders() public {
        deployMock();

        assertEq(token.totalFounders(), 2);
        assertEq(token.totalFounderOwnership(), 15);

        Founder[] memory fdrs = token.getFounders();

        assertEq(fdrs.length, 2);

        Founder memory fdr1 = fdrs[0];
        Founder memory fdr2 = fdrs[1];

        assertEq(fdr1.wallet, foundersArr[0].wallet);
        assertEq(fdr1.ownershipPct, foundersArr[0].ownershipPct);
        assertEq(fdr1.vestExpiry, foundersArr[0].vestExpiry);

        assertEq(fdr2.wallet, foundersArr[1].wallet);
        assertEq(fdr2.ownershipPct, foundersArr[1].ownershipPct);
        assertEq(fdr2.vestExpiry, foundersArr[1].vestExpiry);
    }

    function test_MockAuctionUnpause() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        assertEq(token.totalSupply(), 3);

        assertEq(token.ownerOf(0), founder);
        assertEq(token.ownerOf(1), founder2);
        assertEq(token.ownerOf(2), address(auction));

        assertEq(token.balanceOf(founder), 1);
        assertEq(token.balanceOf(founder2), 1);
        assertEq(token.balanceOf(address(auction)), 1);

        assertEq(token.getVotes(founder), 1);
        assertEq(token.getVotes(founder2), 1);
        assertEq(token.getVotes(address(auction)), 1);
    }

    function test_MaxOwnership100Founders() public {
        createUsers(100, 1 ether);

        address[] memory wallets = new address[](100);
        uint256[] memory percents = new uint256[](100);
        uint256[] memory vestExpirys = new uint256[](100);

        uint256 pct = 1;
        uint256 end = 4 weeks;

        unchecked {
            for (uint256 i; i < 100; ++i) {
                wallets[i] = otherUsers[i];
                percents[i] = pct;
                vestExpirys[i] = end;
            }
        }

        deployWithCustomFounders(wallets, percents, vestExpirys);

        assertEq(token.totalFounders(), 100);
        assertEq(token.totalFounderOwnership(), 100);

        Founder memory founder;

        for (uint256 i; i < 100; ++i) {
            founder = token.getScheduledRecipient(i);

            assertEq(founder.wallet, otherUsers[i]);
        }
    }

    function test_MaxOwnership50Founders() public {
        createUsers(50, 1 ether);

        address[] memory wallets = new address[](50);
        uint256[] memory percents = new uint256[](50);
        uint256[] memory vestExpirys = new uint256[](50);

        uint256 pct = 2;
        uint256 end = 4 weeks;

        unchecked {
            for (uint256 i; i < 50; ++i) {
                wallets[i] = otherUsers[i];
                percents[i] = pct;
                vestExpirys[i] = end;
            }
        }

        deployWithCustomFounders(wallets, percents, vestExpirys);

        assertEq(token.totalFounders(), 50);
        assertEq(token.totalFounderOwnership(), 100);

        Founder memory founder;

        for (uint256 i; i < 50; ++i) {
            founder = token.getScheduledRecipient(i);

            assertEq(founder.wallet, otherUsers[i]);

            founder = token.getScheduledRecipient(i + 50);

            assertEq(founder.wallet, otherUsers[i]);
        }
    }

    function test_MaxOwnership2Founders() public {
        createUsers(2, 1 ether);

        address[] memory wallets = new address[](2);
        uint256[] memory percents = new uint256[](2);
        uint256[] memory vestExpirys = new uint256[](2);

        uint256 pct = 50;
        uint256 end = 4 weeks;

        unchecked {
            for (uint256 i; i < 2; ++i) {
                wallets[i] = otherUsers[i];
                percents[i] = pct;
                vestExpirys[i] = end;
            }
        }

        deployWithCustomFounders(wallets, percents, vestExpirys);

        assertEq(token.totalFounders(), 2);
        assertEq(token.totalFounderOwnership(), 100);

        Founder memory founder;

        unchecked {
            for (uint256 i; i < 500; ++i) {
                founder = token.getScheduledRecipient(i);

                if (i % 2 == 0) assertEq(founder.wallet, otherUsers[0]);
                else assertEq(founder.wallet, otherUsers[1]);
            }
        }
    }

    // Test that when tokens are minted / burned over time,
    // no two tokens end up with the same ID
    function test_TokenIdCollisionAvoidance(uint8 mintCount) public {
        deployMock();

        // avoid overflows specific to this test, shouldn't occur in practice
        vm.assume(mintCount < 100);

        uint256 ts = token.totalSupply();
        uint256 lastTokenId = UINT256_MAX;

        for (uint8 i = 0; i <= mintCount; i++) {
            vm.prank(address(auction));
            uint256 tokenId = token.mint();

            assertFalse(tokenId == lastTokenId);
            lastTokenId = tokenId;

            vm.prank(address(auction));
            token.burn(tokenId);
        }
    }

    function test_FounderScheduleRounding() public {
        createUsers(3, 1 ether);

        address[] memory wallets = new address[](3);
        uint256[] memory percents = new uint256[](3);
        uint256[] memory vestExpirys = new uint256[](3);

        percents[0] = 11;
        percents[1] = 12;
        percents[2] = 13;

        unchecked {
            for (uint256 i; i < 3; ++i) {
                wallets[i] = otherUsers[i];
                vestExpirys[i] = 4 weeks;
            }
        }

        deployWithCustomFounders(wallets, percents, vestExpirys);
    }

    function test_FounderScheduleRounding2() public {
        createUsers(11, 1 ether);

        address[] memory wallets = new address[](11);
        uint256[] memory percents = new uint256[](11);
        uint256[] memory vestExpirys = new uint256[](11);

        percents[0] = 1;
        percents[1] = 1;
        percents[2] = 1;
        percents[3] = 1;
        percents[4] = 1;

        percents[5] = 10;
        percents[6] = 10;
        percents[7] = 10;
        percents[8] = 10;
        percents[9] = 10;

        percents[10] = 20;

        unchecked {
            for (uint256 i; i < 11; ++i) {
                wallets[i] = otherUsers[i];
                vestExpirys[i] = 4 weeks;
            }
        }

        deployWithCustomFounders(wallets, percents, vestExpirys);
    }

    function test_OverwriteCheckpointWithSameTimestamp() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        assertEq(token.balanceOf(founder), 1);
        assertEq(token.getVotes(founder), 1);
        assertEq(token.delegates(founder), founder);

        (uint256 nextTokenId, , , , , ) = auction.auction();

        vm.deal(founder, 1 ether);

        vm.prank(founder);
        auction.createBid{ value: 0.5 ether }(nextTokenId); // Checkpoint #0, Timestamp 1 sec

        vm.warp(block.timestamp + 10 minutes); // Checkpoint #1, Timestamp 10 min + 1 sec

        auction.settleCurrentAndCreateNewAuction();

        assertEq(token.balanceOf(founder), 2);
        assertEq(token.getVotes(founder), 2);
        assertEq(token.delegates(founder), founder);

        vm.prank(founder);
        token.delegate(address(this)); // Checkpoint #1 overwrite

        assertEq(token.getVotes(founder), 0);
        assertEq(token.delegates(founder), address(this));
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.getVotes(address(this)), 2);

        vm.prank(founder);
        token.delegate(founder); // Checkpoint #1 overwrite

        assertEq(token.getVotes(founder), 2);
        assertEq(token.delegates(founder), founder);
        assertEq(token.getVotes(address(this)), 0);

        vm.warp(block.timestamp + 1); // Checkpoint #2, Timestamp 10 min + 2 sec

        vm.prank(founder);
        token.transferFrom(founder, address(this), 0);

        assertEq(token.getVotes(founder), 1);

        // Ensure the votes returned from the binary search is the latest overwrite of checkpoint 1
        assertEq(token.getPastVotes(founder, block.timestamp - 1), 2);
    }

    function testRevert_OnlyAuctionCanMint() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        vm.expectRevert(abi.encodeWithSignature("ONLY_AUCTION()"));
        token.mint();
    }

    function testRevert_OnlyAuctionCanBurn() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        vm.expectRevert(abi.encodeWithSignature("ONLY_AUCTION()"));
        token.burn(1);
    }

    function testRevert_OnlyDAOCanUpgrade() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        vm.expectRevert(abi.encodeWithSignature("ONLY_OWNER()"));
        token.upgradeTo(address(this));
    }

    function testRevert_OnlyDAOCanUpgradeToAndCall() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        vm.expectRevert(abi.encodeWithSignature("ONLY_OWNER()"));
        token.upgradeToAndCall(address(this), "");
    }
}
