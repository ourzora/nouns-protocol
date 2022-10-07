// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { NounsBuilderTest } from "./utils/NounsBuilderTest.sol";

import { IManager } from "../src/manager/IManager.sol";
import { IGovernor } from "../src/governance/governor/IGovernor.sol";
import { GovernorTypesV1 } from "../src/governance/governor/types/GovernorTypesV1.sol";

import { console2 } from "forge-std/console2.sol";

contract E2ETest is NounsBuilderTest {
    function setUp() public virtual override {
        super.setUp();
    }

    /// Test that the percentages for founders all ends up as expected
    function test_FounderShareAllocationFuzz(
        address f1Wallet,
        address f2Wallet,
        address f3Wallet,
        uint8 f1Percentage,
        uint8 f2Percentage,
        uint8 f3Percentage
    ) public {
        vm.assume(f1Wallet != address(0) && f2Wallet != address(0) && f3Wallet != address(0));
        vm.assume(f1Wallet != f2Wallet && f2Wallet != f3Wallet && f1Wallet != f3Wallet);
        vm.assume(f1Percentage > 0 && f1Percentage < 100);
        vm.assume(f2Percentage > 0 && f2Percentage < 100);
        vm.assume(f3Percentage > 0 && f3Percentage < 100);
        vm.assume(f1Percentage + f2Percentage + f3Percentage < 99);

        address[] memory founders = new address[](3);
        uint8[] memory percents = new uint8[](3);
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

        // lol just run a bunch
        uint256 MINT_COUNT = 100;

        // off-by-1 percentages feel fine;
        uint256 maxDelta = 1;

        setFounderParams(founders, percents, vestingEnds);
        setMockTokenParams();
        setMockAuctionParams();
        setMockGovParams();

        deploy(foundersArr, tokenParams, auctionParams, govParams);

        while (token.totalSupply() < MINT_COUNT) {
            vm.prank(address(auction));
            token.mint();
        }

        uint256 expectedF1Alloc = (f1Percentage * MINT_COUNT) / 100;
        assertApproxEqAbs(token.balanceOf(f1Wallet), expectedF1Alloc, maxDelta);
        uint256 expectedF2Alloc = (f2Percentage * MINT_COUNT) / 100;
        assertApproxEqAbs(token.balanceOf(f2Wallet), expectedF2Alloc, maxDelta);
        uint256 expectedF3Alloc = (f3Percentage * MINT_COUNT) / 100;
        assertApproxEqAbs(token.balanceOf(f3Wallet), expectedF3Alloc, maxDelta);
    }
}
