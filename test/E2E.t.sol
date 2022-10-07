// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { NounsBuilderTest } from "./utils/NounsBuilderTest.sol";

import { IManager } from "../src/manager/IManager.sol";
import { IGovernor } from "../src/governance/governor/IGovernor.sol";
import { GovernorTypesV1 } from "../src/governance/governor/types/GovernorTypesV1.sol";

contract E2ETest is NounsBuilderTest {
    function setUp() public virtual override {
        super.setUp();
    }

    mapping(address => uint256) public mintedTokens;

    /// Test that the percentages for founders all ends up as expected
    function test_FounderShareAllocationFuzz(
        uint8 f1Percentage,
        uint8 f2Percentage,
        uint8 f3Percentage
    ) public {
        address f1Wallet = address(0x1);
        address f2Wallet = address(0x2);
        address f3Wallet = address(0x3);
        vm.assume(f1Percentage > 0 && f1Percentage < 100);
        vm.assume(f2Percentage > 0 && f2Percentage < 100);
        vm.assume(f3Percentage > 0 && f3Percentage < 100);
        vm.assume(uint256(f1Percentage) + uint256(f2Percentage) + uint256(f3Percentage) < 99);

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

        // lol just run a bunch
        uint256 MINT_COUNT = 100;

        // off-by-1 percentages feel fine;
        uint256 maxDelta = 1;

        setFounderParams(founders, percents, vestingEnds);
        setMockTokenParams();
        setMockAuctionParams();
        setMockGovParams();

        deploy(foundersArr, tokenParams, auctionParams, govParams);

        // This adds up to 100 total mints with allocations
        for (uint256 i = 0; i < MINT_COUNT; i++) {
            vm.prank(address(auction));
            token.mint();
        }

        // Read the ownership of only the first 100 minted tokens
        // Note that the # of tokens minted above can exceed 100, therefore 
        // we do our own count because we cannot use balanceOf().

        // Clear memory
        mintedTokens[f1Wallet] = 0;
        mintedTokens[f2Wallet] = 0;
        mintedTokens[f3Wallet] = 0;
        for (uint256 i = 0; i < 100; i++) {
            mintedTokens[token.ownerOf(i)] += 1;
        }

        uint256 expectedF1Alloc = uint256(f1Percentage);
        assertEq(mintedTokens[f1Wallet], expectedF1Alloc);
        uint256 expectedF2Alloc = uint256(f2Percentage);
        assertEq(mintedTokens[f2Wallet], expectedF2Alloc);
        uint256 expectedF3Alloc = uint256(f3Percentage);
        assertEq(mintedTokens[f3Wallet], expectedF3Alloc);
    }
}
