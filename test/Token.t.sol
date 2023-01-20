// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { NounsBuilderTest } from "./utils/NounsBuilderTest.sol";

import { IManager, Manager } from "../src/manager/Manager.sol";
import { IToken, Token } from "../src/token/Token.sol";
import { TokenTypesV1 } from "../src/token/types/TokenTypesV1.sol";
import { TokenTypesV2 } from "../src/token/types/TokenTypesV2.sol";

contract TokenTest is NounsBuilderTest, TokenTypesV1 {
    mapping(address => uint256) public mintedTokens;

    function setUp() public virtual override {
        super.setUp();
    }

    function test_MockTokenInit() public {
        deployMock();

        assertEq(token.name(), "Mock Token");
        assertEq(token.symbol(), "MOCK");
        assertEq(token.auction(), address(auction));
        // Initial token owner until first auction is the founder.
        assertEq(token.owner(), address(founder));
        assertEq(token.metadataRenderer(), address(metadataRenderer));
        assertEq(token.totalSupply(), 0);
    }

    /// Test that the percentages for founders all ends up as expected
    function test_FounderShareAllocationFuzz(
        uint256 f1Percentage,
        uint256 f2Percentage,
        uint256 f3Percentage
    ) public {
        address f1Wallet = address(0x1);
        address f2Wallet = address(0x2);
        address f3Wallet = address(0x3);

        vm.assume(f1Percentage > 0 && f1Percentage < 100);
        vm.assume(f2Percentage > 0 && f2Percentage < 100);
        vm.assume(f3Percentage > 0 && f3Percentage < 100);
        vm.assume(f1Percentage + f2Percentage + f3Percentage < 99);

        address[] memory founders = new address[](3);
        uint256[] memory percents = new uint256[](3);
        uint256[] memory vestingEnds = new uint256[](3);

        founders[0] = f1Wallet;
        founders[1] = f2Wallet;
        founders[2] = f3Wallet;

        percents[0] = f1Percentage;
        percents[1] = f2Percentage;
        percents[2] = f3Percentage;

        vestingEnds[0] = 4 weeks;
        vestingEnds[1] = 4 weeks;
        vestingEnds[2] = 4 weeks;

        deployWithCustomFounders(founders, percents, vestingEnds);

        Founder memory f1 = token.getFounder(0);
        Founder memory f2 = token.getFounder(1);
        Founder memory f3 = token.getFounder(2);

        assertEq(f1.ownershipPct, f1Percentage);
        assertEq(f2.ownershipPct, f2Percentage);
        assertEq(f3.ownershipPct, f3Percentage);

        // Mint 100 tokens
        for (uint256 i = 0; i < 100; i++) {
            vm.prank(address(auction));
            token.mint();

            mintedTokens[token.ownerOf(i)] += 1;
        }

        // Read the ownership of only the first 100 minted tokens
        // Note that the # of tokens minted above can exceed 100, therefore
        // we do our own count because we cannot use balanceOf().

        assertEq(mintedTokens[f1Wallet], f1Percentage);
        assertEq(mintedTokens[f2Wallet], f2Percentage);
        assertEq(mintedTokens[f3Wallet], f3Percentage);
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

    function test_MaxOwnership99Founders() public {
        createUsers(100, 1 ether);

        address[] memory wallets = new address[](100);
        uint256[] memory percents = new uint256[](100);
        uint256[] memory vestExpirys = new uint256[](100);

        uint8 pct = 1;
        uint256 end = 4 weeks;

        unchecked {
            for (uint256 i; i < 99; ++i) {
                wallets[i] = otherUsers[i];
                percents[i] = pct;
                vestExpirys[i] = end;
            }
        }

        deployWithCustomFounders(wallets, percents, vestExpirys);

        // Last founder is omitted so total number of founders is 99
        assertEq(token.totalFounders(), 99);
        assertEq(token.totalFounderOwnership(), 99);

        Founder memory thisFounder;

        for (uint256 i; i < 99; ++i) {
            thisFounder = token.getScheduledRecipient(i);

            assertEq(thisFounder.wallet, otherUsers[i]);
        }
    }

    function test_MaxOwnership50Founders() public {
        createUsers(50, 1 ether);

        address[] memory wallets = new address[](50);
        uint256[] memory percents = new uint256[](50);
        uint256[] memory vestExpirys = new uint256[](50);

        uint8 pct = 2;
        uint256 end = 4 weeks;

        unchecked {
            for (uint256 i; i < 50; ++i) {
                wallets[i] = otherUsers[i];
                percents[i] = pct;
                vestExpirys[i] = end;
            }
        }
        percents[49] = 1;

        deployWithCustomFounders(wallets, percents, vestExpirys);

        assertEq(token.totalFounders(), 50);
        assertEq(token.totalFounderOwnership(), 99);

        Founder memory thisFounder;

        for (uint256 i; i < 49; ++i) {
            thisFounder = token.getScheduledRecipient(i);

            assertEq(thisFounder.wallet, otherUsers[i]);

            thisFounder = token.getScheduledRecipient(i + 50);

            assertEq(thisFounder.wallet, otherUsers[i]);
        }
    }

    function test_MaxOwnership2Founders() public {
        createUsers(2, 1 ether);

        address[] memory wallets = new address[](2);
        uint256[] memory percents = new uint256[](2);
        uint256[] memory vestExpirys = new uint256[](2);

        uint8 pct = 49;
        uint256 end = 4 weeks;

        unchecked {
            for (uint256 i; i < 2; ++i) {
                wallets[i] = otherUsers[i];
                vestExpirys[i] = end;
                percents[i] = pct;
            }
        }

        deployWithCustomFounders(wallets, percents, vestExpirys);

        assertEq(token.totalFounders(), 2);
        assertEq(token.totalFounderOwnership(), 98);

        Founder memory thisFounder;

        unchecked {
            for (uint256 i; i < 500; ++i) {
                thisFounder = token.getScheduledRecipient(i);

                if (i % 100 >= 98) {
                    continue;
                }

                if (i % 2 == 0) {
                    assertEq(thisFounder.wallet, otherUsers[0]);
                } else {
                    assertEq(thisFounder.wallet, otherUsers[1]);
                }
            }
        }
    }

    // Test that when tokens are minted / burned over time,
    // no two tokens end up with the same ID
    function test_TokenIdCollisionAvoidance(uint8 mintCount) public {
        deployMock();

        // avoid overflows specific to this test, shouldn't occur in practice
        vm.assume(mintCount < 100);

        uint256 lastTokenId = type(uint256).max;

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

    function test_AuctionCanMintAfterDeploy() public {
        deployMock();

        vm.prank(founder);
        auction.unpause();

        vm.expectRevert(abi.encodeWithSignature("ONLY_AUCTION_OR_MINTER()"));
        token.mint();

        vm.prank(address(auction));
        uint256 tokenId = token.mint();
        assertEq(token.ownerOf(tokenId), address(auction));
    }

    function testRevert_OnlyMinterCanMint(address newMinter, address nonMinter) public {
        vm.assume(newMinter != nonMinter && newMinter != founder && newMinter != address(0) && newMinter != address(auction));
        deployMock();

        TokenTypesV2.MinterParams memory params = TokenTypesV2.MinterParams({ minter: newMinter, allowed: true });
        TokenTypesV2.MinterParams[] memory minters = new TokenTypesV2.MinterParams[](1);
        minters[0] = params;
        vm.prank(address(founder));
        token.updateMinters(minters);

        vm.expectRevert(abi.encodeWithSignature("ONLY_AUCTION_OR_MINTER()"));
        vm.prank(nonMinter);
        token.mint();
        vm.prank(newMinter);
        uint256 tokenId = token.mint();
        assertEq(token.ownerOf(tokenId), newMinter);
    }

    function testRevert_OnlyMinterCanMintToRecipient(
        address newMinter,
        address nonMinter,
        address recipient
    ) public {
        vm.assume(
            newMinter != nonMinter && newMinter != founder && newMinter != address(0) && newMinter != address(auction) && recipient != address(0)
        );
        deployMock();

        TokenTypesV2.MinterParams memory params = TokenTypesV2.MinterParams({ minter: newMinter, allowed: true });
        TokenTypesV2.MinterParams[] memory minters = new TokenTypesV2.MinterParams[](1);
        minters[0] = params;
        vm.prank(address(founder));
        token.updateMinters(minters);

        vm.expectRevert(abi.encodeWithSignature("ONLY_AUCTION_OR_MINTER()"));
        vm.prank(nonMinter);
        token.mint(recipient);
        vm.prank(newMinter);
        uint256 tokenId = token.mint(recipient);
        assertEq(token.ownerOf(tokenId), recipient);
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

    function testFoundersCannotHaveFullOwnership() public {
        createUsers(2, 1 ether);

        address[] memory wallets = new address[](2);
        uint256[] memory percents = new uint256[](2);
        uint256[] memory vestExpirys = new uint256[](2);

        uint256 end = 4 weeks;
        wallets[0] = otherUsers[0];
        vestExpirys[0] = end;
        wallets[1] = otherUsers[1];
        vestExpirys[1] = end;
        percents[0] = 50;
        percents[1] = 49;

        deployWithCustomFounders(wallets, percents, vestExpirys);

        assertEq(token.totalFounders(), 2);
        assertEq(token.totalFounderOwnership(), 99);

        Founder memory thisFounder;

        unchecked {
            for (uint256 i; i < 99; ++i) {
                thisFounder = token.getScheduledRecipient(i);

                if (i % 2 == 0) {
                    assertEq(thisFounder.wallet, otherUsers[0]);
                } else {
                    assertEq(thisFounder.wallet, otherUsers[1]);
                }
            }
        }

        vm.prank(otherUsers[0]);
        auction.unpause();
    }

    function testFoundersCreateZeroOwnershipOmitted() public {
        createUsers(2, 1 ether);

        address[] memory wallets = new address[](2);
        uint256[] memory percents = new uint256[](2);
        uint256[] memory vestExpirys = new uint256[](2);

        uint256 end = 4 weeks;
        wallets[0] = otherUsers[0];
        vestExpirys[0] = end;
        wallets[1] = otherUsers[1];
        vestExpirys[1] = end;
        percents[0] = 0;
        percents[1] = 50;

        deployWithCustomFounders(wallets, percents, vestExpirys);

        assertEq(token.totalFounders(), 1);
        assertEq(token.totalFounderOwnership(), 50);

        unchecked {
            for (uint256 i; i < 99; ++i) {
                if (i % 2 == 0) {
                    Founder memory thisFounder = token.getScheduledRecipient(i);
                    assertEq(thisFounder.wallet, otherUsers[1]);
                }
            }
        }

        vm.prank(otherUsers[0]);
        auction.unpause();
    }

    function testRevert_OnlyOwnerUpdateFounders() public {
        deployMock();

        address f1Wallet = address(0x1);
        address f2Wallet = address(0x2);
        address f3Wallet = address(0x3);

        address[] memory founders = new address[](3);
        uint256[] memory percents = new uint256[](3);
        uint256[] memory vestingEnds = new uint256[](3);

        founders[0] = f1Wallet;
        founders[1] = f2Wallet;
        founders[2] = f3Wallet;

        percents[0] = 1;
        percents[1] = 2;
        percents[2] = 3;

        vestingEnds[0] = 4 weeks;
        vestingEnds[1] = 4 weeks;
        vestingEnds[2] = 4 weeks;

        setFounderParams(founders, percents, vestingEnds);

        vm.prank(f1Wallet);
        vm.expectRevert(abi.encodeWithSignature("ONLY_OWNER()"));

        token.updateFounders(foundersArr);
    }

    function test_UpdateFoundersZeroOwnership() public {
        deployMock();

        IManager.FounderParams[] memory newFoundersArr = new IManager.FounderParams[](2);
        newFoundersArr[0] = IManager.FounderParams({
            wallet: address(0x06B59d0b6AdCc6A5Dc63553782750dc0b41266a3),
            ownershipPct: 0,
            vestExpiry: 2556057600
        });
        newFoundersArr[1] = IManager.FounderParams({
            wallet: address(0x06B59d0b6AdCc6A5Dc63553782750dc0b41266a3),
            ownershipPct: 10,
            vestExpiry: 2556057600
        });

        vm.prank(address(founder));
        token.updateFounders(newFoundersArr);

        assertEq(token.getFounders().length, 1);
    }

    function test_UpdateFounderShareAllocationFuzz(
        uint256 f1Percentage,
        uint256 f2Percentage,
        uint256 f3Percentage
    ) public {
        deployMock();

        address f1Wallet = address(0x1);
        address f2Wallet = address(0x2);
        address f3Wallet = address(0x3);

        vm.assume(f1Percentage > 0 && f1Percentage < 100);
        vm.assume(f2Percentage > 0 && f2Percentage < 100);
        vm.assume(f3Percentage > 0 && f3Percentage < 100);
        vm.assume(f1Percentage + f2Percentage + f3Percentage < 99);

        address[] memory founders = new address[](3);
        uint256[] memory percents = new uint256[](3);
        uint256[] memory vestingEnds = new uint256[](3);

        founders[0] = f1Wallet;
        founders[1] = f2Wallet;
        founders[2] = f3Wallet;

        percents[0] = f1Percentage;
        percents[1] = f2Percentage;
        percents[2] = f3Percentage;

        vestingEnds[0] = 4 weeks;
        vestingEnds[1] = 4 weeks;
        vestingEnds[2] = 4 weeks;

        setFounderParams(founders, percents, vestingEnds);

        vm.prank(address(founder));
        token.updateFounders(foundersArr);

        Founder memory f1 = token.getFounder(0);
        Founder memory f2 = token.getFounder(1);
        Founder memory f3 = token.getFounder(2);

        assertEq(f1.ownershipPct, f1Percentage);
        assertEq(f2.ownershipPct, f2Percentage);
        assertEq(f3.ownershipPct, f3Percentage);

        // Mint 100 tokens
        for (uint256 i = 0; i < 100; i++) {
            vm.prank(address(auction));
            token.mint();

            mintedTokens[token.ownerOf(i)] += 1;
        }

        // Read the ownership of only the first 100 minted tokens
        // Note that the # of tokens minted above can exceed 100, therefore
        // we do our own count because we cannot use balanceOf().

        assertEq(mintedTokens[f1Wallet], f1Percentage);
        assertEq(mintedTokens[f2Wallet], f2Percentage);
        assertEq(mintedTokens[f3Wallet], f3Percentage);
    }

    function test_UpdateMintersOwnerCanAddMinters(address m1, address m2) public {
        vm.assume(
            m1 != founder && m1 != address(0) && m1 != address(auction) && m2 != founder && m2 != address(0) && m2 != address(auction) && m1 != m2
        );

        deployMock();

        TokenTypesV2.MinterParams memory p1 = TokenTypesV2.MinterParams({ minter: m1, allowed: true });
        TokenTypesV2.MinterParams memory p2 = TokenTypesV2.MinterParams({ minter: m2, allowed: true });
        TokenTypesV2.MinterParams[] memory minters = new TokenTypesV2.MinterParams[](2);
        minters[0] = p1;
        minters[1] = p2;

        vm.prank(address(founder));
        token.updateMinters(minters);

        assertTrue(token.minter(minters[0].minter));
        assertTrue(token.minter(minters[1].minter));

        vm.prank(minters[0].minter);
        uint256 tokenId = token.mint();
        assertEq(token.ownerOf(tokenId), minters[0].minter);

        vm.prank(minters[1].minter);
        tokenId = token.mint();
        assertEq(token.ownerOf(tokenId), minters[1].minter);
    }

    function test_UpdateMintersOwnerCanRemoveMinters(address m1, address m2) public {
        vm.assume(
            m1 != founder && m1 != address(0) && m1 != address(auction) && m2 != founder && m2 != address(0) && m2 != address(auction) && m1 != m2
        );

        deployMock();

        // authorize two minters
        TokenTypesV2.MinterParams memory p1 = TokenTypesV2.MinterParams({ minter: m1, allowed: true });
        TokenTypesV2.MinterParams memory p2 = TokenTypesV2.MinterParams({ minter: m2, allowed: true });
        TokenTypesV2.MinterParams[] memory minters = new TokenTypesV2.MinterParams[](2);
        minters[0] = p1;
        minters[1] = p2;

        vm.prank(address(founder));
        token.updateMinters(minters);

        assertTrue(token.minter(minters[0].minter));
        assertTrue(token.minter(minters[1].minter));

        vm.prank(minters[0].minter);
        uint256 tokenId = token.mint();
        assertEq(token.ownerOf(tokenId), minters[0].minter);

        vm.prank(minters[1].minter);
        tokenId = token.mint();
        assertEq(token.ownerOf(tokenId), minters[1].minter);

        // remove authorization from one minter
        minters[1].allowed = false;
        vm.prank(address(founder));
        token.updateMinters(minters);

        assertTrue(token.minter(minters[0].minter));
        assertTrue(!token.minter(minters[1].minter));

        vm.prank(minters[1].minter);
        vm.expectRevert(abi.encodeWithSignature("ONLY_AUCTION_OR_MINTER()"));
        token.mint();
    }

    function testRevert_OnlyOwnerUpdateMinters() public {
        deployMock();

        TokenTypesV2.MinterParams memory p1 = TokenTypesV2.MinterParams({ minter: address(0x1), allowed: true });
        TokenTypesV2.MinterParams memory p2 = TokenTypesV2.MinterParams({ minter: address(0x2), allowed: true });
        TokenTypesV2.MinterParams[] memory minters = new TokenTypesV2.MinterParams[](2);
        minters[0] = p1;
        minters[1] = p2;

        vm.expectRevert(abi.encodeWithSignature("ONLY_OWNER()"));
        token.updateMinters(minters);
    }

    function test_MinterCanBurnTheirOwnToken(address newMinter) public {
        vm.assume(newMinter != founder && newMinter != address(0) && newMinter != address(auction));

        deployMock();

        TokenTypesV2.MinterParams memory p1 = TokenTypesV2.MinterParams({ minter: newMinter, allowed: true });
        TokenTypesV2.MinterParams[] memory minters = new TokenTypesV2.MinterParams[](1);
        minters[0] = p1;

        vm.prank(address(founder));
        token.updateMinters(minters);

        vm.prank(minters[0].minter);
        uint256 tokenId = token.mint();
        assertEq(token.ownerOf(tokenId), minters[0].minter);

        vm.prank(minters[0].minter);
        token.burn(tokenId);
        vm.expectRevert(abi.encodeWithSignature("INVALID_OWNER()"));
        token.ownerOf(tokenId);
    }
}
