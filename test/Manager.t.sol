// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {NounsBuilderTest} from "./utils/NounsBuilderTest.sol";

import {IManager, Manager} from "../src/manager/Manager.sol";

contract ManagerTest is NounsBuilderTest {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_GetAddresses() public {
        deploy();

        (address _metadata, address _auction, address _treasury, address _governor) = manager.getAddresses(address(token));

        assertEq(address(metadataRenderer), _metadata);
        assertEq(address(auction), _auction);
        assertEq(address(timelock), _treasury);
        assertEq(address(governor), _governor);
    }

    function test_TokenInitialized() public {
        deploy();

        assertEq(token.owner(), founder);
        assertEq(token.auction(), address(auction));
        assertEq(token.totalSupply(), 0);
    }

    function test_MetadataRendererInitialized() public {
        deploy();

        assertEq(metadataRenderer.owner(), founder);
    }

    function test_AuctionInitialized() public {
        deploy();

        assertEq(auction.owner(), founder);

        (address _timelock, uint40 _duration, uint40 _timeBuffer, uint16 _minBidIncrementPercentage, uint256 _reservePrice) = auction.settings();

        assertEq(_timelock, address(timelock));
        assertEq(_duration, auctionParams.duration);
        assertEq(_reservePrice, auctionParams.reservePrice);
        assertEq(_timeBuffer, 5 minutes);
        assertEq(_minBidIncrementPercentage, 10);

        assertTrue(auction.paused());
    }

    function test_TreasuryInitialized() public {
        deploy();

        assertEq(timelock.owner(), address(governor));
        assertEq(timelock.delay(), govParams.timelockDelay);
    }

    function test_GovernorInitialized() public {
        deploy();

        assertEq(governor.owner(), address(timelock));
        assertEq(governor.votingDelay(), govParams.votingDelay);
        assertEq(governor.votingPeriod(), govParams.votingPeriod);
    }

    function test_DeployWithoutFounder() public {
        tokenInitStrings = abi.encode(
            "Mock Token",
            "MOCK",
            "This is a mock token",
            "ipfs://Qmew7TdyGnj6YRUjQR68sUJN3239MYXRD8uxowxF6rGK8j",
            "http://localhost:5000/render"
        );

        founderParamsArr.push();

        tokenParams = IManager.TokenParams({initStrings: tokenInitStrings});
        auctionParams = IManager.AuctionParams({reservePrice: 0.01 ether, duration: 10 minutes});

        govParams = IManager.GovParams({
            timelockDelay: 2 days,
            votingDelay: 1,
            votingPeriod: 1 days,
            proposalThresholdBPS: 500,
            quorumVotesBPS: 1000
        });

        vm.expectRevert(abi.encodeWithSignature("FOUNDER_REQUIRED()"));
        deploy(founderParamsArr, tokenParams, auctionParams, govParams);
    }
}
