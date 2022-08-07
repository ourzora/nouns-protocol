// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {BuilderDAOToken} from "../src/builderDAO/BuilderDAOToken.sol";
import {BuilderDAOAuction} from "../src/builderDAO/BuilderDAOAuction.sol";

import {IToken, Token} from "../src/token/Token.sol";
import {IAuction, Auction} from "../src/auction/Auction.sol";

import {IMetadataRenderer, MetadataRenderer} from "../src/token/metadata/MetadataRenderer.sol";
import {IUpgradeManager, UpgradeManager} from "../src/upgrade/UpgradeManager.sol";
import {IDeployer, Deployer} from "../src/Deployer.sol";
import {IGovernor, Governor} from "../src/governance/governor/Governor.sol";
import {ITreasury, Treasury} from "../src/governance/treasury/Treasury.sol";

import {WETH} from "./utils/WETH.sol";

contract BuilderDAOTest is Test {
    UpgradeManager internal upgradeManager;
    Deployer internal deployer;

    address internal nounsDAO;
    address internal zora;
    address internal weth;

    address internal builderDAOTokenImpl;
    address internal builderDAOAuctionImpl;

    address internal tokenImpl;
    address internal auctionImpl;
    address internal metadataRendererImpl;
    address internal treasuryImpl;
    address internal governorImpl;

    address internal deployerImpl;
    address internal deployerV2Impl;

    function setUp() public virtual {
        weth = address(new WETH());

        nounsDAO = vm.addr(0xA11CE);
        zora = vm.addr(0xB0B);

        vm.label(nounsDAO, "NOUNS_DAO");
        vm.label(zora, "ZORA");

        upgradeManager = new UpgradeManager(zora);

        builderDAOTokenImpl = address(new BuilderDAOToken(address(upgradeManager)));
        builderDAOAuctionImpl = address(new BuilderDAOAuction(address(upgradeManager), weth));

        metadataRendererImpl = address(new MetadataRenderer(address(upgradeManager)));
        treasuryImpl = address(new Treasury(address(upgradeManager)));
        governorImpl = address(new Governor(address(upgradeManager)));
        deployerImpl = address(new Deployer(builderDAOTokenImpl, metadataRendererImpl, builderDAOAuctionImpl, treasuryImpl, governorImpl));
    }

    ///                                                          ///
    ///                      BUILDER DAO DEPLOY                  ///
    ///                                                          ///

    bytes internal tokeninitStrings;

    IDeployer.TokenParams internal tokenParams;
    IDeployer.AuctionParams internal auctionParams;
    IDeployer.GovParams internal govParams;

    IToken internal builderDAOToken;
    IMetadataRenderer internal builderDAOMetadataRenderer;
    IAuction internal builderDAOAuction;
    ITreasury internal builderDAOTreasury;
    IGovernor internal builderDAOGovernor;

    function deployBuilderDAO() public {
        tokeninitStrings = abi.encode(
            "Builder DAO",
            "BUILD",
            "The Builder DAO Governance Token",
            "ipfs://Qmew7TdyGnj6YRUjQR68sUJN3239MYXRD8uxowxF6rGK8j",
            "http://localhost:5000/render"
        );

        tokenParams = IDeployer.TokenParams({
            initStrings: tokeninitStrings,
            foundersDAO: nounsDAO,
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

        builderDAOToken = IToken(_token);
        builderDAOMetadataRenderer = IMetadataRenderer(_metadata);
        builderDAOAuction = IAuction(_auction);
        builderDAOTreasury = ITreasury(_treasury);
        builderDAOGovernor = IGovernor(_governor);

        vm.label(address(builderDAOToken), "BUILDER_DAO_TOKEN");
        vm.label(address(builderDAOMetadataRenderer), "BUILDER_DAO_METADATA_RENDERER");
        vm.label(address(builderDAOAuction), "BUILDER_DAO_AUCTION");
        vm.label(address(builderDAOTreasury), "BUILDER_DAO_TREASURY");
        vm.label(address(builderDAOGovernor), "BUILDER_DAO_GOVERNOR");
    }

    function deployV2Deployer() public {
        tokenImpl = address(new Token(address(upgradeManager), address(builderDAOTreasury)));
        auctionImpl = address(new Auction(address(upgradeManager), weth, nounsDAO, 100, address(builderDAOTreasury), 100));

        deployerV2Impl = address(new Deployer(tokenImpl, metadataRendererImpl, auctionImpl, treasuryImpl, governorImpl));

        vm.prank(address(builderDAOTreasury)); // TODO make this via gov
        deployer.upgradeTo(deployerV2Impl);
    }

    ///                                                          ///
    ///                             TEST                         ///
    ///                                                          ///

    function test_DeployNounsBuilder() public {
        // #1: NOUNS DAO DEPLOYS PROXY INSTANCE OF DEPLOYER
        deployer = Deployer(address(new ERC1967Proxy(deployerImpl, abi.encodeWithSignature("initialize(address)", nounsDAO))));

        // #2: NOUNS DAO DEPLOYS THE NOUNS BUILDER DAO
        deployBuilderDAO();

        // #3: NOUNS DAO TRANSFERS OWNERSHIP OF THE DEPLOYER TO BUILDER DAO
        vm.prank(nounsDAO);
        deployer.transferOwnership(address(builderDAOTreasury));

        // #4: BUILDER DAO DEPLOYS UPDATED DEPLOYER
        deployV2Deployer();
    }
}
