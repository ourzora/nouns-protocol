// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {NounsBuilderTest} from "./utils/NounsBuilderTest.sol";

contract DeployerTest is NounsBuilderTest {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_GetAddresses() public {
        deploy();

        (address _metadata, address _auction, address _treasury, address _governor) = deployer.getAddresses(address(token));

        assertEq(address(metadataRenderer), _metadata);
        assertEq(address(auction), _auction);
        assertEq(address(treasury), _treasury);
        assertEq(address(governor), _governor);
    }

    function test_TokenInitialized() public {
        deploy();

        assertEq(token.owner(), foundersDAO);
        // assertEq(token.auction(), address(auction));
        // assertEq(token.totalSupply(), 0);

        // assertEq(token.founders().DAO, tokenParams.foundersDAO);
        // assertEq(token.founders().maxAllocation, tokenParams.foundersMaxAllocation);
        // assertEq(token.founders().allocationFrequency, tokenParams.foundersAllocationFrequency);
        // assertEq(token.founders().currentAllocation, 0);
    }

    function test_MetadataRendererInitialized() public {
        deploy();

        assertEq(metadataRenderer.owner(), foundersDAO);
    }

    function test_AuctionInitialized() public {
        deploy();

        assertEq(auction.owner(), foundersDAO);
        assertEq(auction.house().timeBuffer, 5 minutes);
        assertEq(auction.house().reservePrice, auctionParams.reservePrice);
        assertEq(auction.house().minBidIncrementPercentage, 10);
        assertEq(auction.house().duration, auctionParams.duration);

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
