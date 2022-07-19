// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/test.sol";

import {Deployer} from "../../src/Deployer.sol";
import {IDeployer} from "../../src/IDeployer.sol";

import {IUpgradeManager, UpgradeManager} from "../../src/upgrade/UpgradeManager.sol";

import {IToken, Token} from "../../src/token/Token.sol";
import {IMetadataRenderer, MetadataRenderer} from "../../src/token/metadata/MetadataRenderer.sol";
import {IAuction, Auction} from "../../src/auction/Auction.sol";
import {IGovernor, Governor} from "../../src/governance/governor/Governor.sol";
import {ITreasury, Treasury} from "../../src/governance/treasury/Treasury.sol";

import {WETH} from ".././utils/WETH.sol";

contract NounsBuilderTest is Test {
    ///                                                          ///
    ///                        DEPLOYER SETUP                    ///
    ///                                                          ///

    Deployer internal deployer;
    UpgradeManager internal upgradeManager;

    address internal tokenImpl;
    address internal metadataRendererImpl;
    address internal auctionImpl;
    address internal treasuryImpl;
    address internal governorImpl;

    address internal nounsDAO;
    address internal nounsBuilderDAO;
    address internal foundersDAO;
    address internal weth;

    function setUp() public virtual {
        weth = address(new WETH());

        nounsDAO = vm.addr(0xA11CE);
        nounsBuilderDAO = vm.addr(0xB0B);
        foundersDAO = vm.addr(0xCAB);

        vm.label(nounsDAO, "NOUNS_DAO");
        vm.label(nounsBuilderDAO, "NOUNS_BUILDER_DAO");
        vm.label(foundersDAO, "FOUNDERS_DAO");

        upgradeManager = new UpgradeManager(nounsBuilderDAO);

        tokenImpl = address(new Token(address(upgradeManager)));
        metadataRendererImpl = address(new MetadataRenderer(address(upgradeManager)));
        auctionImpl = address(new Auction(address(upgradeManager), weth, nounsDAO, 100, nounsBuilderDAO, 100));
        treasuryImpl = address(new Treasury(address(upgradeManager)));
        governorImpl = address(new Governor(address(upgradeManager)));

        deployer = new Deployer(tokenImpl, metadataRendererImpl, auctionImpl, treasuryImpl, governorImpl);
    }

    ///                                                          ///
    ///                        MOCK DAO DEPLOY                   ///
    ///                                                          ///

    bytes internal tokeninitStrings;

    IDeployer.TokenParams internal tokenParams;
    IDeployer.AuctionParams internal auctionParams;
    IDeployer.GovParams internal govParams;

    IToken internal token;
    IMetadataRenderer internal metadataRenderer;
    IAuction internal auction;
    ITreasury internal treasury;
    IGovernor internal governor;

    function deploy() public {
        tokeninitStrings = abi.encode(
            "Mock Token",
            "MOCK",
            "This is a mock token",
            "ipfs://Qmew7TdyGnj6YRUjQR68sUJN3239MYXRD8uxowxF6rGK8j",
            "http://localhost:5000/render?"
        );

        tokenParams = IDeployer.TokenParams({
            initStrings: tokeninitStrings,
            foundersDAO: foundersDAO,
            foundersMaxAllocation: 100,
            foundersAllocationFrequency: 5
        });

        auctionParams = IDeployer.AuctionParams({reservePrice: 0.01 ether, duration: 10 minutes});

        govParams = IDeployer.GovParams({
            timelockDelay: 2 days,
            votingDelay: 1, // 1 block
            votingPeriod: 1 days,
            proposalThresholdBPS: 500,
            quorumVotesBPS: 1000
        });

        (address _token, address _metadata, address _auction, address _treasury, address _governor) = deployer.deploy(
            tokenParams,
            auctionParams,
            govParams
        );

        token = IToken(_token);
        metadataRenderer = IMetadataRenderer(_metadata);
        auction = IAuction(_auction);
        treasury = ITreasury(_treasury);
        governor = IGovernor(_governor);

        vm.label(address(token), "TOKEN");
        vm.label(address(metadataRenderer), "METADATA_RENDERER");
        vm.label(address(auction), "AUCTION");
        vm.label(address(treasury), "TREASURY");
        vm.label(address(governor), "GOVERNOR");
    }
}
