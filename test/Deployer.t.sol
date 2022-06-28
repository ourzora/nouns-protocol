// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {NounsBuilderTest} from "./utils/NounsBuilderTest.sol";

contract DeployerTest is NounsBuilderTest {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_TokenInitialized() public {
        deploy();

        assertEq(token.owner(), foundersDAO);
        assertEq(token.auction(), address(auction));
        assertEq(token.totalSupply(), 0);

        assertEq(token.founders().DAO, tokenParams.foundersDAO);
        assertEq(token.founders().maxAllocation, tokenParams.foundersMaxAllocation);
        assertEq(token.founders().allocationFrequency, tokenParams.foundersAllocationFrequency);
        assertEq(token.founders().currentAllocation, 0);
    }

    function test_MetadataRendererInitialized() public {
        deploy();

        assertEq(metadataRenderer.owner(), foundersDAO);
    }

    function test_AuctionInitialized() public {
        deploy();

        assertEq(auction.owner(), foundersDAO);
        assertEq(auction.timeBuffer(), auctionParams.timeBuffer);
        assertEq(auction.reservePrice(), auctionParams.reservePrice);
        assertEq(auction.minBidIncrementPercentage(), auctionParams.minBidIncrementPercentage);
        assertEq(auction.duration(), auctionParams.duration);

        assertTrue(auction.paused());
    }

    function test_TreasuryInitialized() public {
        deploy();

        assertTrue(treasury.hasRole(treasury.TIMELOCK_ADMIN_ROLE(), address(governor)));
        assertTrue(treasury.hasRole(treasury.PROPOSER_ROLE(), address(governor)));
        assertTrue(treasury.hasRole(treasury.EXECUTOR_ROLE(), address(governor)));
        assertTrue(treasury.hasRole(treasury.CANCELLER_ROLE(), address(governor)));

        assertEq(treasury.getMinDelay(), govParams.timelockDelay);
    }

    function test_GovernorInitialized() public {
        deploy();

        assertEq(governor.votingDelay(), govParams.votingDelay);
        assertEq(governor.votingPeriod(), govParams.votingPeriod);
    }
}
