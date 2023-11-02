// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { NounsBuilderTest } from "./utils/NounsBuilderTest.sol";
import { MerkleReserveMinter } from "../src/minters/MerkleReserveMinter.sol";
import { TokenTypesV2 } from "../src/token/types/TokenTypesV2.sol";

contract MerkleReserveMinterTest is NounsBuilderTest {
    MerkleReserveMinter public minter;

    address internal claimer1;
    address internal claimer2;

    function setUp() public virtual override {
        super.setUp();

        minter = new MerkleReserveMinter(address(manager), rewards);
        claimer1 = address(0xC1);
        claimer2 = address(0xC2);
    }

    function deployAltMock(uint256 _reservedUntilTokenId) internal virtual {
        setMockFounderParams();

        setMockTokenParamsWithReserve(_reservedUntilTokenId);

        setMockAuctionParams();

        setMockGovParams();

        deploy(foundersArr, tokenParams, auctionParams, govParams);

        setMockMetadata();
    }

    function deployAltMockAndSetMinter(
        uint256 _reservedUntilTokenId,
        address _minter,
        MerkleReserveMinter.MerkleMinterSettings memory _minterData
    ) internal virtual {
        setMockFounderParams();

        setMockTokenParamsWithReserve(_reservedUntilTokenId);

        setMockAuctionParams();

        setMockGovParams();

        deploy(foundersArr, tokenParams, auctionParams, govParams);

        setMockMetadata();

        TokenTypesV2.MinterParams[] memory minters = new TokenTypesV2.MinterParams[](1);
        minters[0] = TokenTypesV2.MinterParams({ minter: _minter, allowed: true });

        vm.startPrank(token.owner());
        token.updateMinters(minters);
        minter.setMintSettings(address(token), _minterData);
        vm.stopPrank();
    }

    function test_MintFlow() public {
        deployAltMock(20);

        bytes32 root = bytes32(0x5e0da80989496579de029b8ad2f9c234e8de75f5487035210bfb7676e386af8b);

        MerkleReserveMinter.MerkleMinterSettings memory settings = MerkleReserveMinter.MerkleMinterSettings({
            mintStart: 0,
            mintEnd: uint64(block.timestamp + 1000),
            pricePerToken: 0 ether,
            merkleRoot: root
        });

        vm.prank(address(founder));
        minter.setMintSettings(address(token), settings);

        (uint64 mintStart, uint64 mintEnd, uint64 pricePerToken, bytes32 merkleRoot) = minter.allowedMerkles(address(token));
        assertEq(mintStart, settings.mintStart);
        assertEq(mintEnd, settings.mintEnd);
        assertEq(pricePerToken, settings.pricePerToken);
        assertEq(merkleRoot, settings.merkleRoot);

        TokenTypesV2.MinterParams memory params = TokenTypesV2.MinterParams({ minter: address(minter), allowed: true });
        TokenTypesV2.MinterParams[] memory minters = new TokenTypesV2.MinterParams[](1);
        minters[0] = params;
        vm.prank(address(founder));
        token.updateMinters(minters);

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = bytes32(0xd77d6d8eeae66a03ce8ecdba82c6a0ce9cff76f7a4a6bc2bdc670680d3714273);

        MerkleReserveMinter.MerkleClaim[] memory claims = new MerkleReserveMinter.MerkleClaim[](1);
        claims[0] = MerkleReserveMinter.MerkleClaim({ mintTo: claimer1, tokenId: 5, merkleProof: proof });

        minter.mintFromReserve(address(token), claims);

        assertEq(token.ownerOf(5), claimer1);
    }

    function test_MintFlowSetFromToken() public {
        bytes32 root = bytes32(0x5e0da80989496579de029b8ad2f9c234e8de75f5487035210bfb7676e386af8b);

        MerkleReserveMinter.MerkleMinterSettings memory settings = MerkleReserveMinter.MerkleMinterSettings({
            mintStart: 0,
            mintEnd: uint64(block.timestamp + 1000),
            pricePerToken: 0 ether,
            merkleRoot: root
        });

        deployAltMockAndSetMinter(20, address(minter), settings);

        (uint64 mintStart, uint64 mintEnd, uint64 pricePerToken, bytes32 merkleRoot) = minter.allowedMerkles(address(token));
        assertEq(mintStart, settings.mintStart);
        assertEq(mintEnd, settings.mintEnd);
        assertEq(pricePerToken, settings.pricePerToken);
        assertEq(merkleRoot, settings.merkleRoot);

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = bytes32(0xd77d6d8eeae66a03ce8ecdba82c6a0ce9cff76f7a4a6bc2bdc670680d3714273);

        MerkleReserveMinter.MerkleClaim[] memory claims = new MerkleReserveMinter.MerkleClaim[](1);
        claims[0] = MerkleReserveMinter.MerkleClaim({ mintTo: claimer1, tokenId: 5, merkleProof: proof });

        minter.mintFromReserve(address(token), claims);

        assertEq(token.ownerOf(5), claimer1);
    }

    function test_MintFlowWithValue() public {
        deployAltMock(20);

        bytes32 root = bytes32(0x5e0da80989496579de029b8ad2f9c234e8de75f5487035210bfb7676e386af8b);

        MerkleReserveMinter.MerkleMinterSettings memory settings = MerkleReserveMinter.MerkleMinterSettings({
            mintStart: 0,
            mintEnd: uint64(block.timestamp + 1000),
            pricePerToken: 0.5 ether,
            merkleRoot: root
        });

        vm.prank(address(founder));
        minter.setMintSettings(address(token), settings);

        TokenTypesV2.MinterParams memory params = TokenTypesV2.MinterParams({ minter: address(minter), allowed: true });
        TokenTypesV2.MinterParams[] memory minters = new TokenTypesV2.MinterParams[](1);
        minters[0] = params;
        vm.prank(address(founder));
        token.updateMinters(minters);

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = bytes32(0xd77d6d8eeae66a03ce8ecdba82c6a0ce9cff76f7a4a6bc2bdc670680d3714273);

        MerkleReserveMinter.MerkleClaim[] memory claims = new MerkleReserveMinter.MerkleClaim[](1);
        claims[0] = MerkleReserveMinter.MerkleClaim({ mintTo: claimer1, tokenId: 5, merkleProof: proof });

        uint256 fees = minter.getTotalFeesForMint(address(token), claims.length);

        vm.deal(claimer1, fees);
        vm.prank(claimer1);
        minter.mintFromReserve{ value: fees }(address(token), claims);

        assertEq(token.ownerOf(5), claimer1);
        assertEq(address(treasury).balance, fees - minter.BUILDER_DAO_FEE());
    }

    function test_MintFlowWithValueMultipleTokens() public {
        deployAltMock(20);

        bytes32 root = bytes32(0x5e0da80989496579de029b8ad2f9c234e8de75f5487035210bfb7676e386af8b);

        MerkleReserveMinter.MerkleMinterSettings memory settings = MerkleReserveMinter.MerkleMinterSettings({
            mintStart: 0,
            mintEnd: uint64(block.timestamp + 1000),
            pricePerToken: 0.5 ether,
            merkleRoot: root
        });

        vm.prank(address(founder));
        minter.setMintSettings(address(token), settings);

        TokenTypesV2.MinterParams memory params = TokenTypesV2.MinterParams({ minter: address(minter), allowed: true });
        TokenTypesV2.MinterParams[] memory minters = new TokenTypesV2.MinterParams[](1);
        minters[0] = params;
        vm.prank(address(founder));
        token.updateMinters(minters);

        bytes32[] memory proof1 = new bytes32[](1);
        proof1[0] = bytes32(0xd77d6d8eeae66a03ce8ecdba82c6a0ce9cff76f7a4a6bc2bdc670680d3714273);

        bytes32[] memory proof2 = new bytes32[](1);
        proof2[0] = bytes32(0x1845cf6ae7e4ea2bf7813e2b8bc2c114d32bd93817b2f113543c4e0ebc1f38d2);

        MerkleReserveMinter.MerkleClaim[] memory claims = new MerkleReserveMinter.MerkleClaim[](2);
        claims[0] = MerkleReserveMinter.MerkleClaim({ mintTo: claimer1, tokenId: 5, merkleProof: proof1 });
        claims[1] = MerkleReserveMinter.MerkleClaim({ mintTo: claimer2, tokenId: 6, merkleProof: proof2 });

        uint256 fees = minter.getTotalFeesForMint(address(token), claims.length);

        vm.deal(claimer1, fees);
        vm.prank(claimer1);
        minter.mintFromReserve{ value: fees }(address(token), claims);

        assertEq(token.ownerOf(5), claimer1);
        assertEq(token.ownerOf(6), claimer2);
        assertEq(address(treasury).balance, fees - minter.BUILDER_DAO_FEE() * claims.length);
    }

    function testRevert_InvalidValue() public {
        deployAltMock(20);

        bytes32 root = bytes32(0x5e0da80989496579de029b8ad2f9c234e8de75f5487035210bfb7676e386af8b);

        MerkleReserveMinter.MerkleMinterSettings memory settings = MerkleReserveMinter.MerkleMinterSettings({
            mintStart: 0,
            mintEnd: uint64(block.timestamp + 1000),
            pricePerToken: 0.5 ether,
            merkleRoot: root
        });

        vm.prank(address(founder));
        minter.setMintSettings(address(token), settings);

        TokenTypesV2.MinterParams memory params = TokenTypesV2.MinterParams({ minter: address(minter), allowed: true });
        TokenTypesV2.MinterParams[] memory minters = new TokenTypesV2.MinterParams[](1);
        minters[0] = params;
        vm.prank(address(founder));
        token.updateMinters(minters);

        bytes32[] memory proof1 = new bytes32[](1);
        proof1[0] = bytes32(0xd77d6d8eeae66a03ce8ecdba82c6a0ce9cff76f7a4a6bc2bdc670680d3714273);

        bytes32[] memory proof2 = new bytes32[](1);
        proof2[0] = bytes32(0x1845cf6ae7e4ea2bf7813e2b8bc2c114d32bd93817b2f113543c4e0ebc1f38d2);

        MerkleReserveMinter.MerkleClaim[] memory claims = new MerkleReserveMinter.MerkleClaim[](2);
        claims[0] = MerkleReserveMinter.MerkleClaim({ mintTo: claimer1, tokenId: 5, merkleProof: proof1 });
        claims[1] = MerkleReserveMinter.MerkleClaim({ mintTo: claimer2, tokenId: 6, merkleProof: proof2 });

        vm.deal(claimer1, 1 ether);
        vm.prank(claimer1);
        vm.expectRevert(abi.encodeWithSignature("INVALID_VALUE()"));
        minter.mintFromReserve{ value: 0.5 ether }(address(token), claims);
    }

    function testRevert_MintNotStarted() public {
        deployAltMock(20);

        bytes32 root = bytes32(0x5e0da80989496579de029b8ad2f9c234e8de75f5487035210bfb7676e386af8b);

        MerkleReserveMinter.MerkleMinterSettings memory settings = MerkleReserveMinter.MerkleMinterSettings({
            mintStart: uint64(block.timestamp + 999),
            mintEnd: uint64(block.timestamp + 1000),
            pricePerToken: 0 ether,
            merkleRoot: root
        });

        vm.prank(address(founder));
        minter.setMintSettings(address(token), settings);

        TokenTypesV2.MinterParams memory params = TokenTypesV2.MinterParams({ minter: address(minter), allowed: true });
        TokenTypesV2.MinterParams[] memory minters = new TokenTypesV2.MinterParams[](1);
        minters[0] = params;
        vm.prank(address(founder));
        token.updateMinters(minters);

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = bytes32(0xd77d6d8eeae66a03ce8ecdba82c6a0ce9cff76f7a4a6bc2bdc670680d3714273);

        MerkleReserveMinter.MerkleClaim[] memory claims = new MerkleReserveMinter.MerkleClaim[](1);
        claims[0] = MerkleReserveMinter.MerkleClaim({ mintTo: claimer1, tokenId: 5, merkleProof: proof });

        vm.expectRevert(abi.encodeWithSignature("MINT_NOT_STARTED()"));
        minter.mintFromReserve(address(token), claims);
    }

    function testRevert_MintEnded() public {
        deployAltMock(20);

        bytes32 root = bytes32(0x5e0da80989496579de029b8ad2f9c234e8de75f5487035210bfb7676e386af8b);

        MerkleReserveMinter.MerkleMinterSettings memory settings = MerkleReserveMinter.MerkleMinterSettings({
            mintStart: uint64(0),
            mintEnd: uint64(1),
            pricePerToken: 0 ether,
            merkleRoot: root
        });

        vm.prank(address(founder));
        minter.setMintSettings(address(token), settings);

        TokenTypesV2.MinterParams memory params = TokenTypesV2.MinterParams({ minter: address(minter), allowed: true });
        TokenTypesV2.MinterParams[] memory minters = new TokenTypesV2.MinterParams[](1);
        minters[0] = params;
        vm.prank(address(founder));
        token.updateMinters(minters);

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = bytes32(0xd77d6d8eeae66a03ce8ecdba82c6a0ce9cff76f7a4a6bc2bdc670680d3714273);

        MerkleReserveMinter.MerkleClaim[] memory claims = new MerkleReserveMinter.MerkleClaim[](1);
        claims[0] = MerkleReserveMinter.MerkleClaim({ mintTo: claimer1, tokenId: 5, merkleProof: proof });

        vm.warp(3);
        vm.expectRevert(abi.encodeWithSignature("MINT_ENDED()"));
        minter.mintFromReserve(address(token), claims);
    }

    function testRevert_InvalidProof() public {
        deployAltMock(20);

        bytes32 root = bytes32(0x5e0da80989496579de029b8ad2f9c234e8de75f5487035210bfb7676e386af8b);

        MerkleReserveMinter.MerkleMinterSettings memory settings = MerkleReserveMinter.MerkleMinterSettings({
            mintStart: uint64(0),
            mintEnd: uint64(block.timestamp + 1000),
            pricePerToken: 0 ether,
            merkleRoot: root
        });

        vm.prank(address(founder));
        minter.setMintSettings(address(token), settings);

        TokenTypesV2.MinterParams memory params = TokenTypesV2.MinterParams({ minter: address(minter), allowed: true });
        TokenTypesV2.MinterParams[] memory minters = new TokenTypesV2.MinterParams[](1);
        minters[0] = params;
        vm.prank(address(founder));
        token.updateMinters(minters);

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = bytes32(0xf77d6d8eeae66a03ce8ecdba82c6a0ce9cff76f7a4a6bc2bdc670680d3714273);

        MerkleReserveMinter.MerkleClaim[] memory claims = new MerkleReserveMinter.MerkleClaim[](1);
        claims[0] = MerkleReserveMinter.MerkleClaim({ mintTo: claimer1, tokenId: 5, merkleProof: proof });

        vm.expectRevert(abi.encodeWithSignature("INVALID_MERKLE_PROOF(address,bytes32[],bytes32)", claimer1, proof, root));
        minter.mintFromReserve(address(token), claims);
    }

    function test_ResetMint() public {
        deployAltMock(20);

        bytes32 root = bytes32(0x5e0da80989496579de029b8ad2f9c234e8de75f5487035210bfb7676e386af8b);

        MerkleReserveMinter.MerkleMinterSettings memory settings = MerkleReserveMinter.MerkleMinterSettings({
            mintStart: 0,
            mintEnd: uint64(block.timestamp + 1000),
            pricePerToken: 0 ether,
            merkleRoot: root
        });

        vm.prank(address(founder));
        minter.setMintSettings(address(token), settings);

        vm.prank(address(founder));
        minter.resetMintSettings(address(token));

        (uint64 mintStart, uint64 mintEnd, uint64 pricePerToken, bytes32 merkleRoot) = minter.allowedMerkles(address(token));
        assertEq(mintStart, 0);
        assertEq(mintEnd, 0);
        assertEq(pricePerToken, 0);
        assertEq(merkleRoot, bytes32(0));
    }
}
