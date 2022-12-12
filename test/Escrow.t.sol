// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { Test } from "forge-std/Test.sol";
import { Escrow } from "../src/escrow/Escrow.sol";

contract EscrowTest is Test {
    Escrow internal escrow;
    address internal owner;
    address internal claimer;

    function setUp() public {
        owner = vm.addr(0xA11CE);
        claimer = vm.addr(0xB0B);
        escrow = new Escrow(owner, claimer);
    }

    function test_deploy() public {
        assertEq(escrow.owner(), owner);
        assertEq(escrow.claimer(), claimer);
    }

    function test_setClaimerRevertOnlyOwner() public {
        vm.expectRevert(abi.encodeWithSignature("OnlyOwner()"));
        escrow.setClaimer(owner);
    }

    function test_setClaimer() public {
        address newClaimer = vm.addr(0xCA1);

        vm.prank(owner);
        escrow.setClaimer(newClaimer);

        assertEq(escrow.claimer(), newClaimer);
    }

    function test_claimRevertOnlyClaimer() public {
        vm.expectRevert(abi.encodeWithSignature("OnlyClaimer()"));
        escrow.claim(claimer);
    }

    function test_claim() public {
        uint256 beforeBalance = claimer.balance;
        address(escrow).call{ value: 1 ether }("");

        vm.prank(claimer);
        escrow.claim(claimer);

        uint256 afterBalance = claimer.balance;

        assertEq(afterBalance, beforeBalance + 1 ether);
    }
}
