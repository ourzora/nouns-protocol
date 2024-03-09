// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import { OPAddressAliasHelper } from "../src/lib/utils/OPAddressAliasHelper.sol";
import { IBaseMetadata } from "../src/token/metadata/interfaces/IBaseMetadata.sol";
import { IPropertyIPFSMetadataRenderer } from "../src/token/metadata/interfaces/IPropertyIPFSMetadataRenderer.sol";
import { IToken, Token } from "../src/token/Token.sol";
import { MerkleReserveMinter } from "../src/minters/MerkleReserveMinter.sol";

contract GetInterfaceIds is Script {
    function run() public {
        //console2.logAddress(OPAddressAliasHelper.applyL1ToL2Alias(0x7498e6e471f31e869f038D8DBffbDFdf650c3F95));
        //console2.logBytes4(type(IBaseMetadata).interfaceId);
        console2.logBytes4(type(IPropertyIPFSMetadataRenderer).interfaceId);

        bytes32[] memory proof = new bytes32[](6);
        proof[0] = bytes32(0xe4ea50005878141497528e3da7a85b34149af4aa83a170b61245a302a81e53aa);
        proof[1] = bytes32(0xec2634a7019358ddb4d452b7ab001749267712bcd41879e1066ad208973336e0);
        proof[2] = bytes32(0x7831906a696828681160a4f491f910bd2e6198d7daca53b099516f5a9a247366);
        proof[3] = bytes32(0xc76ae6aa4d55b08facb83bd7b390d1aea947cdcea5ae3ec5fc24ee9f66ebd126);
        proof[4] = bytes32(0x703c891cf5a587e7e8fbe59cc475fd3e7a0161da940143b5859039946f6a82da);
        proof[5] = bytes32(0x5166ccdc1ec7b8e737c8bd8e27bce80f6aefc1c7a4ee80161e5ff0408adacebf);

        MerkleReserveMinter.MerkleClaim[] memory claims = new MerkleReserveMinter.MerkleClaim[](1);
        claims[0] = MerkleReserveMinter.MerkleClaim({ mintTo: 0x27B4a2eB472C280b17B79c315F79C522B038aFCF, tokenId: 11, merkleProof: proof });

        MerkleReserveMinter(0x411A7476b2A197a3b3D5576040B1111F560a8b57).mintFromReserve(0xCa226cDf9f9E27B09dd873f69FD2d0aF33A46a07, claims);
        //Token(0xCa226cDf9f9E27B09dd873f69FD2d0aF33A46a07).mintFromReserveTo(0x27B4a2eB472C280b17B79c315F79C522B038aFCF, 11);
    }
}
