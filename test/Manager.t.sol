// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { NounsBuilderTest } from "./utils/NounsBuilderTest.sol";

import { IManager, Manager } from "../src/manager/Manager.sol";

import { MockImpl } from "./utils/mocks/MockImpl.sol";

contract ManagerTest is NounsBuilderTest {
    MockImpl internal mockImpl;

    address internal builderDAO;

    function setUp() public virtual override {
        super.setUp();

        mockImpl = new MockImpl();
    }

    function test_GetAddresses() public {
        deployMock();

        (address _metadata, address _auction, address _treasury, address _governor) = manager.getAddresses(address(token));

        assertEq(address(metadataRenderer), _metadata);
        assertEq(address(auction), _auction);
        assertEq(address(treasury), _treasury);
        assertEq(address(governor), _governor);
    }

    function test_TokenInitialized() public {
        deployMock();

        assertEq(token.owner(), address(treasury));
        assertEq(token.auction(), address(auction));
        assertEq(token.totalSupply(), 0);
    }

    function test_MetadataRendererInitialized() public {
        deployMock();

        assertEq(metadataRenderer.owner(), address(treasury));
    }

    function test_DerivedAddresses() public {
        assertEq(address(manager), address(0x42997aC9251E5BB0A61F4Ff790E5B991ea07Fd9B));
        (address _metadata, address _auction, address _treasury, address _governor) = manager.getAddresses(address(0x123456));
        assertEq(_metadata, address(0x96FA53596F55014Efc3B7c7b557df2227a43f0da));
        assertEq(_auction, address(0x897dB62ebE788a11dE2cB4221cA86F57f252F3E5));
        assertEq(_treasury, address(0x8EFFFc5f3DDbA015eb4F6A557ec674Eced4C1915));
        assertEq(_governor, address(0xBAe859323C44e31421aA354A22541d7d5a04d4fD));
    }

    function test_AuctionInitialized() public {
        deployMock();

        assertEq(auction.owner(), founder);
        assertTrue(auction.paused());

        assertEq(auction.treasury(), address(treasury));
        assertEq(auction.duration(), auctionParams.duration);
        assertEq(auction.reservePrice(), auctionParams.reservePrice);
        assertEq(auction.timeBuffer(), 5 minutes);
        assertEq(auction.minBidIncrement(), 10);
    }

    function test_TreasuryInitialized() public {
        deployMock();

        assertEq(treasury.owner(), address(governor));
        assertEq(treasury.delay(), govParams.timelockDelay);
    }

    function test_GovernorInitialized() public {
        deployMock();

        assertEq(governor.owner(), address(treasury));
        assertEq(governor.votingDelay(), govParams.votingDelay);
        assertEq(governor.votingPeriod(), govParams.votingPeriod);
    }

    function testRevert_DeployWithoutFounder() public {
        setMockTokenParams();

        setMockAuctionParams();

        setMockGovParams();

        foundersArr.push();

        vm.expectRevert(abi.encodeWithSignature("FOUNDER_REQUIRED()"));
        deploy(foundersArr, tokenParams, auctionParams, govParams);
    }

    function test_RegisterUpgrade() public {
        address owner = manager.owner();

        vm.prank(owner);
        manager.registerUpgrade(tokenImpl, address(mockImpl));

        assertTrue(manager.isRegisteredUpgrade(tokenImpl, address(mockImpl)));
    }

    function test_RemoveUpgrade() public {
        address owner = manager.owner();

        vm.prank(owner);
        manager.registerUpgrade(tokenImpl, address(mockImpl));

        vm.prank(owner);
        manager.removeUpgrade(tokenImpl, address(mockImpl));

        assertFalse(manager.isRegisteredUpgrade(tokenImpl, address(mockImpl)));
    }

    function testRevert_OnlyOwnerCanRegisterUpgrade() public {
        vm.expectRevert(abi.encodeWithSignature("ONLY_OWNER()"));
        manager.registerUpgrade(address(token), address(mockImpl));
    }

    function testRevert_OnlyOwnerCanRemoveUpgrade() public {
        vm.expectRevert(abi.encodeWithSignature("ONLY_OWNER()"));
        manager.removeUpgrade(address(token), address(mockImpl));
    }
}
