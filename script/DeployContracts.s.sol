// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/token/builder/BuilderToken.sol";
import {UpgradeManager} from "../src/upgrade/UpgradeManager.sol";
import {BuilderDAOToken} from "../src/builderDAO/BuilderDAOToken.sol";

import {BuilderDAOToken} from "../src/builderDAO/BuilderDAOToken.sol";
import {BuilderDAOAuction} from "../src/builderDAO/BuilderDAOAuction.sol";

import {IToken, Token} from "../src/token/Token.sol";
import {IAuction, Auction} from "../src/auction/Auction.sol";

import {IMetadataRenderer, MetadataRenderer} from "../src/token/metadata/MetadataRenderer.sol";
import {IUpgradeManager, UpgradeManager} from "../src/upgrade/UpgradeManager.sol";
import {IDeployer, Deployer} from "../src/Deployer.sol";
import {IGovernor, Governor} from "../src/governance/governor/Governor.sol";
import {ITreasury, Treasury} from "../src/governance/treasury/Treasury.sol";

import {MockTreasury} from "./MockTreasury.sol";

contract DeployContracts is Script {
    UpgradeManager upgradeManager;
    address REGISTAR_ADDRESS = address(0x0901);
    address weth;
    address foundersDAO;
    Deployer deployer;

    function setUp() public {
        weth = vm.envAddress("WETH_ADDRESS");
        foundersDAO = vm.envAddress("FOUNDERS_DAO");
    }

    function run() public {
        vm.startBroadcast();
        upgradeManager = new UpgradeManager(REGISTAR_ADDRESS);
        setupContracts();
        vm.stopBroadcast();
    }

    function setupContracts() public {
        address builderDAOTokenImpl = address(new BuilderDAOToken(address(upgradeManager)));
        address builderDAOAuctionImpl = address(new BuilderDAOAuction(address(upgradeManager), weth));

        address mockTreasury = address(new MockTreasury(address(this)));

        address metadataRendererImpl = address(new MetadataRenderer(address(upgradeManager)));
        address treasuryImpl = address(mockTreasury);
        address governorImpl = address(new Governor(address(upgradeManager)));
        deployer = new Deployer(builderDAOTokenImpl, metadataRendererImpl, builderDAOAuctionImpl, treasuryImpl, governorImpl);

        bytes memory tokeninitStrings = abi.encode(
            "Builder DAO",
            "BUILD",
            "The Builder DAO Governance Token",
            "ipfs://Qmew7TdyGnj6YRUjQR68sUJN3239MYXRD8uxowxF6rGK8j",
            "http://localhost:5000/render"
        );

        address nounsDAO = foundersDAO;

        (address _token, address _metadata, address _auction, address _treasury, address _governor) = deployer.deploy(
            IDeployer.TokenParams({initStrings: tokeninitStrings, foundersDAO: nounsDAO, foundersMaxAllocation: 100, foundersAllocationFrequency: 5}),
            IDeployer.AuctionParams({reservePrice: 0.01 ether, duration: 10 minutes}),
            IDeployer.GovParams({
                timelockDelay: 2 days,
                votingDelay: 1, // 1 block
                votingPeriod: 1 days,
                proposalThresholdBPS: 500,
                quorumVotesBPS: 1000
            })
        );

        address correctTreasuryImpl = address(new Treasury(address(upgradeManager)));

        address tokenImpl = address(new Token(address(upgradeManager), _treasury));
        address auctionImpl = address(new Auction(address(upgradeManager), weth, nounsDAO, 100, address(_treasury), 100));

        address deployerV2Impl = address(new Deployer(tokenImpl, _metadata, auctionImpl, correctTreasuryImpl, _governor));

        // builderDAOTreasury
        MockTreasury(_treasury).execute(address(deployer), abi.encodeWithSignature("upgradeTo(address)", deployerV2Impl));
    }
}
