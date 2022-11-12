// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { Test } from "forge-std/Test.sol";
import { Treasury } from "../src/governance/treasury/Treasury.sol";
import { Auction } from "../src/auction/Auction.sol";
import { Token } from "../src/token/Token.sol";
import { Governor } from "../src/governance/governor/Governor.sol";

contract BuilderDAOTest is Test {
    Treasury internal immutable treasury = Treasury(payable(0xDC9b96Ea4966d063Dd5c8dbaf08fe59062091B6D));
    Auction internal immutable auction = Auction(payable(0x658D3A1B6DaBcfbaa8b75cc182Bf33efefDC200d));
    Token internal immutable token = Token(0xdf9B7D26c8Fc806b1Ae6273684556761FF02d422);
    Governor internal immutable governor = Governor(0xe3F8d5488C69d18ABda42FCA10c177d7C19e8B1a);
    address internal immutable nounsTreasury = 0x0BC3807Ec262cB779b38D65b38158acC3bfedE10;
    address internal immutable zora = 0xd1d1D4e36117aB794ec5d4c78cBD3a8904E691D0;
    address internal immutable escrow = 0xC20Dac0B62b28eddE0C44aB1BE2206a1c48e6A67;

    function setUp() public {
        uint256 mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);

        vm.prank(zora);
        auction.unpause();
    }

    function test_initialAuctionSetup() public {
        assertEq(token.balanceOf(zora), 1);
        assertEq(token.balanceOf(nounsTreasury), 1);
        assertEq(token.balanceOf(address(auction)), 1);
        assertEq(token.totalFounders(), 2);
        assertEq(token.totalFounderOwnership(), 15);
        assertEq(token.getFounder(0).ownershipPct, 10);
        assertEq(token.getFounder(0).wallet, zora);
        assertEq(token.getFounder(0).vestExpiry, 1825027200);
        assertEq(token.getFounder(1).ownershipPct, 5);
        assertEq(token.getFounder(1).wallet, nounsTreasury);
        assertEq(token.getFounder(1).vestExpiry, 1825027200);
    }

    function test_firstProposals() public {
        address[] memory targets = new address[](4);
        uint256[] memory values = new uint256[](4);
        bytes[] memory calldatas = new bytes[](4);

        targets[0] = address(governor);
        targets[1] = address(governor);
        targets[2] = address(0);
        targets[3] = escrow;
        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        values[3] = 0;
        calldatas[0] = abi.encodeWithSignature("updateVotingDelay(uint256)", 86400);
        calldatas[1] = abi.encodeWithSignature("updateVotingPeriod(uint256)", 345600);
        calldatas[2] = abi.encodeWithSignature("");
        calldatas[3] = abi.encodeWithSignature("claim(address)", address(treasury));

        vm.prank(zora);
        bytes32 proposalId = governor.propose(targets, values, calldatas, "");

        uint256 votingDelay = governor.votingDelay();
        vm.warp(block.timestamp + votingDelay + 1);

        vm.prank(zora);
        governor.castVote(proposalId, 1);

        vm.warp(block.timestamp + governor.votingPeriod());

        vm.prank(zora);
        governor.queue(proposalId);

        vm.warp(block.timestamp + treasury.delay());
        vm.prank(zora);
        bytes32 descriptionHash = keccak256(bytes(""));
        governor.execute(targets, values, calldatas, descriptionHash, zora);

        assertEq(governor.votingDelay(), 86400);
        assertEq(governor.votingPeriod(), 345600);
        assertEq(address(treasury).balance, 1000 * 10**18);
    }
}
