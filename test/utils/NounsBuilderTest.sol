// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

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

    IDeployer.TokenParams internal tokenParams;
    IDeployer.AuctionParams internal auctionParams;
    IDeployer.GovParams internal govParams;

    IToken internal token;
    IMetadataRenderer internal metadataRenderer;
    IAuction internal auction;
    ITreasury internal treasury;
    IGovernor internal governor;

    function setUp() public virtual {
        weth = address(new WETH());

        nounsDAO = vm.addr(0xA11CE);
        nounsBuilderDAO = vm.addr(0xB0B);
        foundersDAO = vm.addr(0xCAB);

        vm.label(nounsDAO, "NounsDAO");
        vm.label(nounsBuilderDAO, "NounsBuilderDAO");
        vm.label(foundersDAO, "FoundersDAO");

        upgradeManager = new UpgradeManager(nounsBuilderDAO);
        metadataRendererImpl = address(new MetadataRenderer());

        tokenImpl = address(new Token(address(upgradeManager), metadataRendererImpl));
        auctionImpl = address(new Auction(address(upgradeManager), nounsDAO, nounsBuilderDAO, weth));
        treasuryImpl = address(new Treasury(address(upgradeManager)));
        governorImpl = address(new Governor(address(upgradeManager)));

        deployer = new Deployer(tokenImpl, auctionImpl, treasuryImpl, governorImpl);
    }

    function deploy() public {
        tokenParams = IDeployer.TokenParams({
            name: "Mock Token",
            symbol: "MOCK",
            foundersDAO: foundersDAO,
            foundersMaxAllocation: 100,
            foundersAllocationFrequency: 5
        });

        auctionParams = IDeployer.AuctionParams({
            timeBuffer: 2 minutes,
            reservePrice: 0.01 ether,
            minBidIncrementPercentage: 5,
            duration: 10 minutes
        });

        govParams = IDeployer.GovParams({timelockDelay: 2 days, votingDelay: 5, votingPeriod: 10, proposalThresholdBPS: 25, quorumVotesBPS: 1000});

        deployer.deploy(tokenParams, auctionParams, govParams);

        (address _token, address _auction, address _treasury, address _governor) = deployer.deploy(tokenParams, auctionParams, govParams);

        token = IToken(_token);
        metadataRenderer = token.metadataRenderer();
        auction = IAuction(_auction);
        treasury = ITreasury(_treasury);
        governor = IGovernor(_governor);
    }
}
