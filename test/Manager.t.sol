// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

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

    function setupAltMock() internal virtual {
        setMockFounderParams();

        setMockTokenParams();

        setMockAuctionParams();

        setMockGovParams();
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

        assertEq(token.owner(), address(founder));
        assertEq(token.auction(), address(auction));
        assertEq(token.totalSupply(), 0);
        vm.prank(founder);
        auction.unpause();
        assertEq(token.owner(), address(treasury));
        assertEq(token.totalSupply(), 3);
    }

    function test_MetadataRendererInitialized() public {
        deployMock();

        assertEq(metadataRenderer.owner(), address(founder));
    }

    function test_GetDAOVersions() public {
        deployMock();

        string memory version = manager.contractVersion();
        IManager.DAOVersionInfo memory versionInfo = manager.getDAOVersions(address(token));
        assertEq(versionInfo.token, version);
        assertEq(versionInfo.metadata, version);
        assertEq(versionInfo.governor, version);
        assertEq(versionInfo.auction, version);
        assertEq(versionInfo.treasury, version);
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
        assertEq(treasury.delay(), treasuryParams.timelockDelay);
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
        deploy(foundersArr, implAddresses, implData);
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

    function test_RegisterImplementation() public {
        address owner = manager.owner();

        vm.prank(owner);
        manager.registerImplementation(0, address(mockImpl));

        assertTrue(manager.isRegisteredImplementation(0, address(mockImpl)));
    }

    function test_RemoveImplementation() public {
        address owner = manager.owner();

        vm.prank(owner);
        manager.registerImplementation(0, address(mockImpl));

        vm.prank(owner);
        manager.removeImplementation(0, address(mockImpl));

        assertFalse(manager.isRegisteredImplementation(0, address(mockImpl)));
    }

    function testRevert_OnlyOwnerCanRegisterImplementation() public {
        vm.expectRevert(abi.encodeWithSignature("ONLY_OWNER()"));
        manager.registerImplementation(0, address(mockImpl));
    }

    function testRevert_OnlyOwnerCanRemoveImplementation() public {
        vm.expectRevert(abi.encodeWithSignature("ONLY_OWNER()"));
        manager.removeImplementation(0, address(mockImpl));
    }

    function testRevert_InvalidImplementationType() public {
        address owner = manager.owner();

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("INVALID_IMPLEMENTATION_TYPE()"));
        manager.registerImplementation(8, address(mockImpl));
    }

    function testRevert_InvalidImplementationAddresses() public {
        address[] memory altImplAddresses = new address[](1);

        setupAltMock();

        vm.expectRevert(abi.encodeWithSignature("INVALID_IMPLEMENTATION_PARAMS()"));
        deploy(foundersArr, altImplAddresses, implData);
    }

    function testRevert_InvalidImplementationData() public {
        bytes[] memory altImplData = new bytes[](1);

        setupAltMock();

        vm.expectRevert(abi.encodeWithSignature("INVALID_IMPLEMENTATION_PARAMS()"));
        deploy(foundersArr, implAddresses, altImplData);
    }

    function testRevert_UnregisteredImplementation() public {
        address[] memory altImplAddresses = new address[](5);
        altImplAddresses[0] = address(24);

        setupAltMock();

        vm.expectRevert(abi.encodeWithSignature("IMPLEMENTATION_NOT_REGISTERED()"));
        deploy(foundersArr, altImplAddresses, implData);
    }
}
