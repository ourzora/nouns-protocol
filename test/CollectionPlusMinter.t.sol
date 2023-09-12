// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { NounsBuilderTest } from "./utils/NounsBuilderTest.sol";
import { MockERC6551Registry } from "./utils/mocks/MockERC6551Registry.sol";
import { MockERC1271 } from "./utils/mocks/MockERC1271.sol";
import { MockERC721 } from "./utils/mocks/MockERC721.sol";
import { CollectionPlusMinter } from "../src/minters/CollectionPlusMinter.sol";
import { PartialSoulboundToken } from "../src/token/partial-soulbound/PartialSoulboundToken.sol";
import { TokenTypesV2 } from "../src/token/default/types/TokenTypesV2.sol";

contract MerkleReserveMinterTest is NounsBuilderTest {
    MockERC6551Registry public erc6551Registry;

    CollectionPlusMinter public minter;
    PartialSoulboundToken soulboundToken;
    MockERC721 public redeemToken;

    address public soulboundTokenImpl;
    address public erc6551Impl;

    address internal claimer;
    uint256 internal claimerPK;

    function setUp() public virtual override {
        super.setUp();
        createClaimer();

        erc6551Impl = address(0x6551);
        redeemToken = new MockERC721();

        erc6551Registry = new MockERC6551Registry(claimer);
        minter = new CollectionPlusMinter(manager, erc6551Registry, erc6551Impl, builderDAO);
    }

    function createClaimer() internal {
        claimerPK = 0xABE;
        claimer = vm.addr(claimerPK);

        vm.deal(claimer, 100 ether);
    }

    function deployAltMock(uint256 _reservedUntilTokenId) internal virtual {
        setMockFounderParams();

        setMockTokenParamsWithReserve(_reservedUntilTokenId);

        setMockAuctionParams();

        setMockGovParams();

        setImplementationAddresses();

        soulboundTokenImpl = address(new PartialSoulboundToken(address(manager)));

        vm.startPrank(zoraDAO);
        manager.registerImplementation(manager.IMPLEMENTATION_TYPE_TOKEN(), soulboundTokenImpl);
        vm.stopPrank();

        implAddresses[manager.IMPLEMENTATION_TYPE_TOKEN()] = soulboundTokenImpl;

        deploy(foundersArr, implAddresses, implData);

        soulboundToken = PartialSoulboundToken(address(token));

        setMockMetadata();
    }

    function test_MintFlow() public {
        deployAltMock(20);

        CollectionPlusMinter.CollectionPlusSettings memory settings = CollectionPlusMinter.CollectionPlusSettings({
            mintStart: 0,
            mintEnd: uint64(block.timestamp + 1000),
            pricePerToken: 0 ether,
            redeemToken: address(redeemToken)
        });

        redeemToken.mint(claimer, 6);

        vm.prank(address(founder));
        minter.setSettings(address(token), settings);

        TokenTypesV2.MinterParams memory minterParams = TokenTypesV2.MinterParams({ minter: address(minter), allowed: true });
        TokenTypesV2.MinterParams[] memory minters = new TokenTypesV2.MinterParams[](1);
        minters[0] = minterParams;
        vm.prank(address(founder));
        token.updateMinters(minters);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 6;

        minter.mintFromReserve(address(token), claimer, tokenIds, "");

        address tokenBoundAccount = erc6551Registry.account(erc6551Impl, block.chainid, address(redeemToken), 6, 0);

        assertEq(soulboundToken.ownerOf(6), tokenBoundAccount);
        assertEq(soulboundToken.locked(6), true);
        assertEq(token.getVotes(tokenBoundAccount), 1);
    }

    function test_ResetSettings() public {
        deployAltMock(20);

        CollectionPlusMinter.CollectionPlusSettings memory settings = CollectionPlusMinter.CollectionPlusSettings({
            mintStart: 0,
            mintEnd: uint64(block.timestamp + 1000),
            pricePerToken: 0 ether,
            redeemToken: address(redeemToken)
        });

        vm.startPrank(address(founder));
        minter.setSettings(address(token), settings);
        minter.resetSettings(address(token));
        vm.stopPrank();

        (uint64 mintStart, uint64 mintEnd, uint64 pricePerToken, address redeem) = minter.allowedCollections(address(token));
        assertEq(mintStart, 0);
        assertEq(mintEnd, 0);
        assertEq(pricePerToken, 0);
        assertEq(redeem, address(0));
    }

    function test_MintFlowWithDelegation() public {
        deployAltMock(20);

        CollectionPlusMinter.CollectionPlusSettings memory settings = CollectionPlusMinter.CollectionPlusSettings({
            mintStart: 0,
            mintEnd: uint64(block.timestamp + 1000),
            pricePerToken: 0 ether,
            redeemToken: address(redeemToken)
        });

        redeemToken.mint(claimer, 6);

        vm.prank(address(founder));
        minter.setSettings(address(token), settings);

        TokenTypesV2.MinterParams memory minterParams = TokenTypesV2.MinterParams({ minter: address(minter), allowed: true });
        TokenTypesV2.MinterParams[] memory minters = new TokenTypesV2.MinterParams[](1);
        minters[0] = minterParams;
        vm.prank(address(founder));
        token.updateMinters(minters);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 6;

        address[] memory fromAddresses = new address[](1);
        fromAddresses[0] = erc6551Registry.account(erc6551Impl, block.chainid, address(redeemToken), 6, 0);

        uint256 deadline = block.timestamp + 100;

        bytes32 digest = token.getBatchDelegateBySigTypedDataHash(fromAddresses, claimer, deadline);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(claimerPK, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        assertEq(token.getVotes(claimer), 0);

        minter.mintFromReserveAndDelegate(address(token), claimer, tokenIds, "", signature, deadline);

        assertEq(soulboundToken.ownerOf(6), fromAddresses[0]);
        assertEq(soulboundToken.locked(6), true);
        assertEq(token.getVotes(claimer), 1);
    }

    function test_MintFlowMultipleTokens() public {
        deployAltMock(20);

        CollectionPlusMinter.CollectionPlusSettings memory settings = CollectionPlusMinter.CollectionPlusSettings({
            mintStart: 0,
            mintEnd: uint64(block.timestamp + 1000),
            pricePerToken: 0 ether,
            redeemToken: address(redeemToken)
        });

        redeemToken.mint(claimer, 6);
        redeemToken.mint(claimer, 7);

        vm.prank(address(founder));
        minter.setSettings(address(token), settings);

        TokenTypesV2.MinterParams memory params = TokenTypesV2.MinterParams({ minter: address(minter), allowed: true });
        TokenTypesV2.MinterParams[] memory minters = new TokenTypesV2.MinterParams[](1);
        minters[0] = params;
        vm.prank(address(founder));
        token.updateMinters(minters);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 6;
        tokenIds[1] = 7;

        minter.mintFromReserve(address(token), claimer, tokenIds, "");

        address tokenBoundAccount1 = erc6551Registry.account(erc6551Impl, block.chainid, address(redeemToken), 6, 0);
        address tokenBoundAccount2 = erc6551Registry.account(erc6551Impl, block.chainid, address(redeemToken), 7, 0);

        assertEq(soulboundToken.ownerOf(6), tokenBoundAccount1);
        assertEq(soulboundToken.locked(6), true);

        assertEq(soulboundToken.ownerOf(7), tokenBoundAccount2);
        assertEq(soulboundToken.locked(7), true);

        assertEq(token.getVotes(tokenBoundAccount1), 1);
        assertEq(token.getVotes(tokenBoundAccount2), 1);
    }

    function test_MintFlowMultipleTokensWithDelegation() public {
        deployAltMock(20);

        CollectionPlusMinter.CollectionPlusSettings memory settings = CollectionPlusMinter.CollectionPlusSettings({
            mintStart: 0,
            mintEnd: uint64(block.timestamp + 1000),
            pricePerToken: 0 ether,
            redeemToken: address(redeemToken)
        });

        redeemToken.mint(claimer, 6);
        redeemToken.mint(claimer, 7);

        vm.prank(address(founder));
        minter.setSettings(address(token), settings);

        TokenTypesV2.MinterParams memory minterParams = TokenTypesV2.MinterParams({ minter: address(minter), allowed: true });
        TokenTypesV2.MinterParams[] memory minters = new TokenTypesV2.MinterParams[](1);
        minters[0] = minterParams;
        vm.prank(address(founder));
        token.updateMinters(minters);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 6;
        tokenIds[1] = 7;

        address[] memory fromAddresses = new address[](2);
        fromAddresses[0] = erc6551Registry.account(erc6551Impl, block.chainid, address(redeemToken), 6, 0);
        fromAddresses[1] = erc6551Registry.account(erc6551Impl, block.chainid, address(redeemToken), 7, 0);

        uint256 deadline = block.timestamp + 100;

        bytes32 digest = token.getBatchDelegateBySigTypedDataHash(fromAddresses, claimer, deadline);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(claimerPK, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        assertEq(token.getVotes(claimer), 0);

        minter.mintFromReserveAndDelegate(address(token), claimer, tokenIds, "", signature, deadline);

        assertEq(soulboundToken.ownerOf(6), fromAddresses[0]);
        assertEq(soulboundToken.locked(6), true);

        assertEq(soulboundToken.ownerOf(7), fromAddresses[1]);
        assertEq(soulboundToken.locked(7), true);

        assertEq(token.getVotes(claimer), 2);
    }

    function test_MintFlowWithFees() public {
        deployAltMock(20);

        CollectionPlusMinter.CollectionPlusSettings memory settings = CollectionPlusMinter.CollectionPlusSettings({
            mintStart: 0,
            mintEnd: uint64(block.timestamp + 1000),
            pricePerToken: 0.01 ether,
            redeemToken: address(redeemToken)
        });

        redeemToken.mint(claimer, 6);
        redeemToken.mint(claimer, 7);

        vm.prank(address(founder));
        minter.setSettings(address(token), settings);

        TokenTypesV2.MinterParams memory minterParams = TokenTypesV2.MinterParams({ minter: address(minter), allowed: true });
        TokenTypesV2.MinterParams[] memory minters = new TokenTypesV2.MinterParams[](1);
        minters[0] = minterParams;
        vm.prank(address(founder));
        token.updateMinters(minters);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 6;
        tokenIds[1] = 7;

        uint256 fees = minter.getTotalFeesForMint(address(token), tokenIds.length);

        uint256 prevTreasuryBalance = address(treasury).balance;
        uint256 prevBuilderBalance = address(builderDAO).balance;
        uint256 builderFee = minter.BUILDER_DAO_FEE() * tokenIds.length;

        minter.mintFromReserve{ value: fees }(address(token), claimer, tokenIds, "");

        assertEq(address(builderDAO).balance, prevBuilderBalance + builderFee);
        assertEq(address(treasury).balance, prevTreasuryBalance + (fees - builderFee));
    }

    function testRevert_MintNotStarted() public {
        deployAltMock(20);

        CollectionPlusMinter.CollectionPlusSettings memory settings = CollectionPlusMinter.CollectionPlusSettings({
            mintStart: uint64(block.timestamp + 999),
            mintEnd: uint64(block.timestamp + 1000),
            pricePerToken: 0.01 ether,
            redeemToken: address(redeemToken)
        });

        redeemToken.mint(claimer, 6);
        redeemToken.mint(claimer, 7);

        vm.prank(address(founder));
        minter.setSettings(address(token), settings);

        TokenTypesV2.MinterParams memory minterParams = TokenTypesV2.MinterParams({ minter: address(minter), allowed: true });
        TokenTypesV2.MinterParams[] memory minters = new TokenTypesV2.MinterParams[](1);
        minters[0] = minterParams;
        vm.prank(address(founder));
        token.updateMinters(minters);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 6;
        tokenIds[1] = 7;

        uint256 fees = minter.getTotalFeesForMint(address(token), tokenIds.length);

        vm.expectRevert(abi.encodeWithSignature("MINT_NOT_STARTED()"));
        minter.mintFromReserve{ value: fees }(address(token), claimer, tokenIds, "");
    }

    function testRevert_MintEnded() public {
        deployAltMock(20);

        CollectionPlusMinter.CollectionPlusSettings memory settings = CollectionPlusMinter.CollectionPlusSettings({
            mintStart: uint64(block.timestamp),
            mintEnd: uint64(block.timestamp + 1),
            pricePerToken: 0.01 ether,
            redeemToken: address(redeemToken)
        });

        vm.warp(block.timestamp + 2);

        redeemToken.mint(claimer, 6);
        redeemToken.mint(claimer, 7);

        vm.prank(address(founder));
        minter.setSettings(address(token), settings);

        TokenTypesV2.MinterParams memory minterParams = TokenTypesV2.MinterParams({ minter: address(minter), allowed: true });
        TokenTypesV2.MinterParams[] memory minters = new TokenTypesV2.MinterParams[](1);
        minters[0] = minterParams;
        vm.prank(address(founder));
        token.updateMinters(minters);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 6;
        tokenIds[1] = 7;

        uint256 fees = minter.getTotalFeesForMint(address(token), tokenIds.length);

        vm.expectRevert(abi.encodeWithSignature("MINT_ENDED()"));
        minter.mintFromReserve{ value: fees }(address(token), claimer, tokenIds, "");
    }

    function testRevert_InvalidValue() public {
        deployAltMock(20);

        CollectionPlusMinter.CollectionPlusSettings memory settings = CollectionPlusMinter.CollectionPlusSettings({
            mintStart: uint64(block.timestamp),
            mintEnd: uint64(block.timestamp + 100),
            pricePerToken: 0.01 ether,
            redeemToken: address(redeemToken)
        });

        vm.warp(block.timestamp + 2);

        redeemToken.mint(claimer, 6);
        redeemToken.mint(claimer, 7);

        vm.prank(address(founder));
        minter.setSettings(address(token), settings);

        TokenTypesV2.MinterParams memory minterParams = TokenTypesV2.MinterParams({ minter: address(minter), allowed: true });
        TokenTypesV2.MinterParams[] memory minters = new TokenTypesV2.MinterParams[](1);
        minters[0] = minterParams;
        vm.prank(address(founder));
        token.updateMinters(minters);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 6;
        tokenIds[1] = 7;

        vm.expectRevert(abi.encodeWithSignature("INVALID_VALUE()"));
        minter.mintFromReserve{ value: 0.0001 ether }(address(token), claimer, tokenIds, "");
    }
}
