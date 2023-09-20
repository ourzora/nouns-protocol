// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { NounsBuilderTest } from "./utils/NounsBuilderTest.sol";
import { MockERC721 } from "./utils/mocks/MockERC721.sol";
import { ERC721RedeemMinter } from "../src/minters/ERC721RedeemMinter.sol";
import { TokenTypesV2 } from "../src/token/default/types/TokenTypesV2.sol";

contract ERC721RedeemMinterTest is NounsBuilderTest {
    ERC721RedeemMinter public minter;

    address internal claimer1;
    address internal claimer2;

    MockERC721 public redeemToken;

    function setUp() public virtual override {
        super.setUp();

        minter = new ERC721RedeemMinter(manager, builderDAO);
        redeemToken = new MockERC721();

        claimer1 = address(0xC1);
        claimer2 = address(0xC2);
    }

    function deployAltMockAndSetMinter(
        uint256 _reservedUntilTokenId,
        address _minter,
        bytes memory _minterData
    ) internal virtual {
        setMockFounderParams();

        setMockTokenParamsWithReserveAndMinter(_reservedUntilTokenId, _minter, _minterData);

        setMockAuctionParams();

        setMockGovParams();

        setImplementationAddresses();

        deploy(foundersArr, implAddresses, implData);

        setMockMetadata();
    }

    function test_MintFlow() public {
        ERC721RedeemMinter.RedeemSettings memory settings = ERC721RedeemMinter.RedeemSettings({
            mintStart: 0,
            mintEnd: uint64(block.timestamp + 1000),
            pricePerToken: 0 ether,
            redeemToken: address(redeemToken)
        });

        deployAltMockAndSetMinter(20, address(minter), abi.encode(settings));

        (uint64 mintStart, uint64 mintEnd, uint64 pricePerToken, address redeem) = minter.redeemSettings(address(token));
        assertEq(mintStart, settings.mintStart);
        assertEq(mintEnd, settings.mintEnd);
        assertEq(pricePerToken, settings.pricePerToken);
        assertEq(redeem, settings.redeemToken);

        redeemToken.mint(claimer1, 4);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 4;

        minter.mintFromReserve(address(token), tokenIds);

        assertEq(token.ownerOf(4), claimer1);
    }

    function test_MintFlowMutliple() public {
        ERC721RedeemMinter.RedeemSettings memory settings = ERC721RedeemMinter.RedeemSettings({
            mintStart: 0,
            mintEnd: uint64(block.timestamp + 1000),
            pricePerToken: 0 ether,
            redeemToken: address(redeemToken)
        });

        deployAltMockAndSetMinter(20, address(minter), abi.encode(settings));

        redeemToken.mint(claimer1, 4);
        redeemToken.mint(claimer1, 5);
        redeemToken.mint(claimer1, 6);

        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 4;
        tokenIds[1] = 5;
        tokenIds[2] = 6;

        minter.mintFromReserve(address(token), tokenIds);

        assertEq(token.ownerOf(4), claimer1);
        assertEq(token.ownerOf(5), claimer1);
        assertEq(token.ownerOf(6), claimer1);
    }

    function testRevert_NotMinted() public {
        ERC721RedeemMinter.RedeemSettings memory settings = ERC721RedeemMinter.RedeemSettings({
            mintStart: 0,
            mintEnd: uint64(block.timestamp + 1000),
            pricePerToken: 0 ether,
            redeemToken: address(redeemToken)
        });

        deployAltMockAndSetMinter(20, address(minter), abi.encode(settings));

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 4;

        vm.expectRevert(abi.encodeWithSignature("NOT_MINTED()"));
        minter.mintFromReserve(address(token), tokenIds);
    }

    function test_MintFlowWithValue() public {
        ERC721RedeemMinter.RedeemSettings memory settings = ERC721RedeemMinter.RedeemSettings({
            mintStart: 0,
            mintEnd: uint64(block.timestamp + 1000),
            pricePerToken: 0.01 ether,
            redeemToken: address(redeemToken)
        });

        deployAltMockAndSetMinter(20, address(minter), abi.encode(settings));

        redeemToken.mint(claimer1, 4);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 4;

        vm.deal(claimer1, 10 ether);

        uint256 balanceBefore = claimer1.balance;
        uint256 totalFees = minter.getTotalFeesForMint(address(token), 1);

        vm.prank(claimer1);
        minter.mintFromReserve{ value: totalFees }(address(token), tokenIds);

        assertEq(balanceBefore - totalFees, claimer1.balance);
        assertEq(token.ownerOf(4), claimer1);
    }

    function test_MintFlowWithValueMultiple() public {
        ERC721RedeemMinter.RedeemSettings memory settings = ERC721RedeemMinter.RedeemSettings({
            mintStart: 0,
            mintEnd: uint64(block.timestamp + 1000),
            pricePerToken: 0.01 ether,
            redeemToken: address(redeemToken)
        });

        deployAltMockAndSetMinter(20, address(minter), abi.encode(settings));

        redeemToken.mint(claimer1, 4);
        redeemToken.mint(claimer1, 5);
        redeemToken.mint(claimer1, 6);

        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 4;
        tokenIds[1] = 5;
        tokenIds[2] = 6;

        vm.deal(claimer1, 10 ether);

        uint256 balanceBefore = claimer1.balance;
        uint256 totalFees = minter.getTotalFeesForMint(address(token), 3);

        vm.prank(claimer1);
        minter.mintFromReserve{ value: totalFees }(address(token), tokenIds);

        assertEq(balanceBefore - totalFees, claimer1.balance);
        assertEq(token.ownerOf(4), claimer1);
        assertEq(token.ownerOf(5), claimer1);
        assertEq(token.ownerOf(6), claimer1);
    }

    function testRevert_MintFlowInvalidValue() public {
        ERC721RedeemMinter.RedeemSettings memory settings = ERC721RedeemMinter.RedeemSettings({
            mintStart: 0,
            mintEnd: uint64(block.timestamp + 1000),
            pricePerToken: 0.01 ether,
            redeemToken: address(redeemToken)
        });

        deployAltMockAndSetMinter(20, address(minter), abi.encode(settings));

        redeemToken.mint(claimer1, 4);
        redeemToken.mint(claimer1, 5);
        redeemToken.mint(claimer1, 6);

        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 4;
        tokenIds[1] = 5;
        tokenIds[2] = 6;

        vm.deal(claimer1, 10 ether);
        vm.prank(claimer1);
        vm.expectRevert(abi.encodeWithSignature("INVALID_VALUE()"));
        minter.mintFromReserve{ value: 0 }(address(token), tokenIds);
    }

    function testRevert_MintNotStarted() public {
        ERC721RedeemMinter.RedeemSettings memory settings = ERC721RedeemMinter.RedeemSettings({
            mintStart: uint64(block.timestamp + 999),
            mintEnd: uint64(block.timestamp + 1000),
            pricePerToken: 0 ether,
            redeemToken: address(redeemToken)
        });

        deployAltMockAndSetMinter(20, address(minter), abi.encode(settings));

        redeemToken.mint(claimer1, 4);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 4;

        vm.expectRevert(abi.encodeWithSignature("MINT_NOT_STARTED()"));
        minter.mintFromReserve(address(token), tokenIds);
    }

    function testRevert_MintEnded() public {
        ERC721RedeemMinter.RedeemSettings memory settings = ERC721RedeemMinter.RedeemSettings({
            mintStart: uint64(block.timestamp),
            mintEnd: uint64(block.timestamp + 1),
            pricePerToken: 0 ether,
            redeemToken: address(redeemToken)
        });

        vm.warp(block.timestamp + 2);

        deployAltMockAndSetMinter(20, address(minter), abi.encode(settings));

        redeemToken.mint(claimer1, 4);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 4;

        vm.expectRevert(abi.encodeWithSignature("MINT_ENDED()"));
        minter.mintFromReserve(address(token), tokenIds);
    }

    function test_ResetMint() public {
        ERC721RedeemMinter.RedeemSettings memory settings = ERC721RedeemMinter.RedeemSettings({
            mintStart: uint64(0),
            mintEnd: uint64(block.timestamp + 100),
            pricePerToken: 0 ether,
            redeemToken: address(redeemToken)
        });

        deployAltMockAndSetMinter(20, address(minter), abi.encode(settings));

        vm.prank(founder);
        minter.resetMintSettings(address(token));

        (uint64 mintStart, uint64 mintEnd, uint64 pricePerToken, address redeem) = minter.redeemSettings(address(token));
        assertEq(mintStart, 0);
        assertEq(mintEnd, 0);
        assertEq(pricePerToken, 0);
        assertEq(redeem, address(0));
    }
}
