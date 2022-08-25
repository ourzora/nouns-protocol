// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {IToken, Token} from "../src/token/Token.sol";
import {IAuction, Auction} from "../src/auction/Auction.sol";

import {MetadataRenderer} from "../src/token/metadata/MetadataRenderer.sol";
import {Manager} from "../src/manager/Manager.sol";
import {IManager} from "../src/manager/IManager.sol";
import {Governor} from "../src/governance/governor/Governor.sol";
import {IGovernor} from "../src/governance/governor/IGovernor.sol";
import {Timelock} from "../src/governance/timelock/Timelock.sol";
import {ITimelock} from "../src/governance/timelock/ITimelock.sol";

import {MockTreasury} from "./MockTreasury.sol";

contract DeployContracts is Script {
    Manager manager;
    address REGISTAR_ADDRESS = address(0x0901);
    address weth;
    address foundersDAO;

    function setUp() public {
        weth = vm.envAddress("WETH_ADDRESS");
        foundersDAO = vm.envAddress("FOUNDERS_DAO");
    }

    function run() public {
        vm.startBroadcast();
        setupContracts();
        vm.stopBroadcast();
    }

    function setupContracts() public {
        address builderDAOTokenImpl = address(new Token(address(manager)));
        address builderDAOAuctionImpl = address(new Auction(address(manager), weth));

        address mockTreasury = address(new MockTreasury(address(this)));

        address metadataRendererImpl = address(new MetadataRenderer(address(manager)));
        address governorImpl = address(new Governor(address(manager)));
        address managerImpl = address(new Manager(builderDAOTokenImpl, metadataRendererImpl, builderDAOAuctionImpl, mockTreasury, governorImpl));

        manager.initialize(foundersDAO);
        Manager manager = Manager(managerImpl);

        bytes memory tokeninitStrings = abi.encode(
            "Builder DAO",
            "BUILD",
            "The Builder DAO Governance Token",
            "ipfs://Qmew7TdyGnj6YRUjQR68sUJN3239MYXRD8uxowxF6rGK8j",
            "http://localhost:5000/render"
        );

        IManager.FounderParams[] memory founderParams = new IManager.FounderParams[](1);

        founderParams[0] = IManager.FounderParams({
            wallet: foundersDAO,
            allocationFrequency: 2,
            vestingEnd: block.timestamp + (2 * 60 * 60 * 30 * 12)
        });

        (address _token, address _metadata, address _auction, address _timelock, address _governor) = manager.deploy(
            founderParams,
            IManager.TokenParams({initStrings: tokeninitStrings}),
            IManager.AuctionParams({reservePrice: 0.01 ether, duration: 10 minutes}),
            IManager.GovParams({
                timelockDelay: 2 days,
                votingDelay: 1, // 1 block
                votingPeriod: 1 days,
                proposalThresholdBPS: 500,
                quorumVotesBPS: 1000
            })
        );

        address correctTimelock = address(new Timelock(address(manager)));

        address tokenImpl = address(new Token(address(manager)));
        address auctionImpl = address(new Auction(address(manager), weth));

        address deployerV2Impl = address(new Manager(tokenImpl, _metadata, auctionImpl, correctTimelock, _governor));

        // builderDAOTreasury
        MockTreasury(mockTreasury).execute(address(manager), abi.encodeWithSignature("upgradeTo(address)", deployerV2Impl));

        console2.log("Manager: ");
        console2.log(address(manager));
        console2.log("Deployer: ");
        console2.log(deployerV2Impl);
    }
}
