// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {IManager} from "../src/manager/IManager.sol";

import {Auction} from "../src/auction/Auction.sol";

contract SetupDaoScript is Script {
    IManager manager;
    address founder;

    function setUp() public {
        manager = IManager(vm.envAddress("MANAGER"));
        founder = vm.envAddress("FOUNDERS_DAO");
    }

    function run() public {
        console2.log(msg.sender);

        vm.startBroadcast();

        IManager.TokenParams memory tokenParams = IManager.TokenParams({
            initStrings: abi.encode(
                "Mock Token",
                "MOCK",
                "This is a mock token",
                "ipfs://Qmew7TdyGnj6YRUjQR68sUJN3239MYXRD8uxowxF6rGK8j",
                "http://localhost:5000/render"
            )
        });

        IManager.AuctionParams memory auctionParams = IManager.AuctionParams({reservePrice: 0.01 ether, duration: 10});

        IManager.FounderParams[] memory founderParams = new IManager.FounderParams[](1);
        founderParams[0] = IManager.FounderParams({
            wallet: founder,
            percentage: 2,
            vestingEnd: block.timestamp + (2 * 60 * 60 * 30 * 12)
        });

        IManager.GovParams memory govParams = IManager.GovParams({
            timelockDelay: 0,
            votingDelay: 0, // 1 block
            votingPeriod: 10,
            proposalThresholdBps: 10,
            quorumThresholdBps: 100
        });

        (address _token, address _metadata, address _auction, address _treasury, address _governor) = manager.deploy(
            founderParams,
            tokenParams,
            auctionParams,
            govParams
        );

        // now that we have a DAO process a proposal
        Auction auction = Auction(_auction);

        auction.setTimeBuffer(0);

        auction.unpause();

        // create auction
        auction.createBid{value: 0.01 ether}(1);

        // string[] memory ffiArgs = new string[](2);
        // ffiArgs[0] = 'sleep';
        // ffiArgs[1] = '20';
        // vm.ffi(ffiArgs);
        // vm.warp(block.timestamp+20);

        // auction.settleCurrentAndCreateNewAuction();

        // // create another auction
        // auction.createBid{value: 0.01 ether}(3);

        // vm.ffi(ffiArgs);
        // vm.warp(block.timestamp+50);

        // auction.settleCurrentAndCreateNewAuction();

        vm.stopBroadcast();
    }
}
