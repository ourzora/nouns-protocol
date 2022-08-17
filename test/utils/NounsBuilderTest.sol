// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";

import {ERC1967Proxy} from "../../src/lib/proxy/ERC1967Proxy.sol";

import {IManager, Manager} from "../../src/manager/Manager.sol";

// import {BuilderToken} from "../../src/builderDAO/BuilderToken.sol";
// import {BuilderAuction} from "../../src/builderDAO/BuilderAuction.sol";

import {IToken, Token} from "../../src/token/Token.sol";
import {IMetadataRenderer, MetadataRenderer} from "../../src/token/metadata/MetadataRenderer.sol";
import {IAuction, Auction} from "../../src/auction/Auction.sol";
import {IGovernor, Governor} from "../../src/governance/governor/Governor.sol";
import {ITimelock, Timelock} from "../../src/governance/timelock/Timelock.sol";

import {WETH} from ".././utils/WETH.sol";

contract NounsBuilderTest is Test {
    ///                                                          ///
    ///                        DEPLOYER SETUP                    ///
    ///                                                          ///

    Manager internal manager;

    address internal managerImpl1;
    address internal managerImpl2;
    address internal managerImpl3;

    address internal tokenImpl;
    address internal metadataRendererImpl;
    address internal auctionImpl;
    address internal timelockImpl;
    address internal governorImpl;

    address internal builderDAO;
    address internal founder;
    address internal weth;

    function setUp() public virtual {
        weth = address(new WETH());

        founder = vm.addr(0xCAB);
        builderDAO = vm.addr(0xB3D);

        vm.label(founder, "FOUNDER");
        vm.label(builderDAO, "BUILDER_DAO");

        // Initial manager
        managerImpl1 = address(new Manager(address(0), address(0), address(0), address(0), address(0)));
        manager = Manager(address(new ERC1967Proxy(managerImpl1, abi.encodeWithSignature("initialize(address)", builderDAO))));

        // Deploy builder impl
        // builderTokenImpl = address(new BuilderToken(address(manager)));
        // builderAuctionImpl = address(new BuilderAuction(address(manager), weth, nounsDAO, zoraDAO));

        metadataRendererImpl = address(new MetadataRenderer(address(manager)));
        timelockImpl = address(new Timelock(address(manager)));
        governorImpl = address(new Governor(address(manager)));

        // Deploy builder manager
        // // managerImpl2 = address(new Manager(builderTokenImpl, metadataRendererImpl, builderAuctionImpl, timelockImpl, governorImpl));

        // vm.prank(zoraDAO);
        // manager.upgradeTo(managerImpl2);

        // builderDAO = deployBuilderDAO();

        tokenImpl = address(new Token(address(manager)));
        auctionImpl = address(new Auction(address(manager), weth));

        managerImpl3 = address(new Manager(tokenImpl, metadataRendererImpl, auctionImpl, timelockImpl, governorImpl));

        vm.prank(builderDAO);
        manager.upgradeTo(managerImpl3);
    }

    ///                                                          ///
    ///                       BUILDER DAO DEPLOY                 ///
    ///                                                          ///

    // address internal builderTokenImpl;
    // address internal builderAuctionImpl;

    // bytes internal builderInitStrings;

    // IManager.FounderParams[] internal builderFounderParamsArr;
    // IManager.TokenParams internal builderTokenParams;
    // IManager.AuctionParams internal builderAuctionParams;
    // IManager.GovParams internal builderGovParams;

    // BuilderToken internal builderToken;
    // BuilderAuction internal builderAuction;
    // MetadataRenderer internal builderMetadataRenderer;
    // Timelock internal builderTimelock;
    // Governor internal builderGovernor;

    // function deployBuilderDAO() internal returns (address) {
    //     builderInitStrings = abi.encode(
    //         "Mock Token",
    //         "MOCK",
    //         "This is a mock token",
    //         "ipfs://Qmew7TdyGnj6YRUjQR68sUJN3239MYXRD8uxowxF6rGK8j",
    //         "http://localhost:5000/render"
    //     );

    //     builderFounderParamsArr.push();
    //     builderFounderParamsArr.push();

    //     builderFounderParamsArr[0] = IManager.FounderParams({wallet: zoraDAO, allocationFrequency: 11, vestingEnd: 4 weeks});
    //     builderFounderParamsArr[1] = IManager.FounderParams({wallet: nounsDAO, allocationFrequency: 20, vestingEnd: 4 weeks});

    //     builderTokenParams = IManager.TokenParams({initStrings: tokenInitStrings});
    //     builderAuctionParams = IManager.AuctionParams({reservePrice: 0.0 ether, duration: 1 days});

    //     builderGovParams = IManager.GovParams({
    //         timelockDelay: 2 days,
    //         votingDelay: 1,
    //         votingPeriod: 1 days,
    //         proposalThresholdBPS: 500,
    //         quorumVotesBPS: 1000
    //     });

    //     (address _token, address _metadata, address _auction, address _timelock, address _governor) = manager.deploy(
    //         builderFounderParamsArr,
    //         builderTokenParams,
    //         builderAuctionParams,
    //         builderGovParams
    //     );

    //     builderToken = BuilderToken(_token);
    //     builderMetadataRenderer = MetadataRenderer(_metadata);
    //     builderAuction = BuilderAuction(_auction);
    //     builderTimelock = Timelock(payable(_timelock));
    //     builderGovernor = Governor(_governor);

    //     vm.label(address(builderToken), "BUILDER_TOKEN");
    //     vm.label(address(builderMetadataRenderer), "BUILDER_METADATA_RENDERER");
    //     vm.label(address(builderAuction), "BUILDER_AUCTION");
    //     vm.label(address(builderTimelock), "BUILDER_TIMELOCK");
    //     vm.label(address(builderGovernor), "BUILDER_GOVERNOR");

    //     return _timelock;
    // }

    ///                                                          ///
    ///                        MOCK DAO DEPLOY                   ///
    ///                                                          ///

    bytes internal tokenInitStrings;

    IManager.FounderParams[] internal founderParamsArr;
    IManager.TokenParams internal tokenParams;
    IManager.AuctionParams internal auctionParams;
    IManager.GovParams internal govParams;

    Token internal token;
    MetadataRenderer internal metadataRenderer;
    Auction internal auction;
    Timelock internal timelock;
    Governor internal governor;

    function deploy() public virtual {
        tokenInitStrings = abi.encode(
            "Mock Token",
            "MOCK",
            "This is a mock token",
            "ipfs://Qmew7TdyGnj6YRUjQR68sUJN3239MYXRD8uxowxF6rGK8j",
            "http://localhost:5000/render"
        );

        founderParamsArr.push();
        founderParamsArr.push();

        founderParamsArr[0] = IManager.FounderParams({wallet: founder, allocationFrequency: 10, vestingEnd: 4 weeks});
        founderParamsArr[1] = IManager.FounderParams({wallet: address(this), allocationFrequency: 20, vestingEnd: 4 weeks});

        tokenParams = IManager.TokenParams({initStrings: tokenInitStrings});
        auctionParams = IManager.AuctionParams({reservePrice: 0.01 ether, duration: 10 minutes});

        govParams = IManager.GovParams({
            timelockDelay: 2 days,
            votingDelay: 1,
            votingPeriod: 1 days,
            proposalThresholdBPS: 500,
            quorumVotesBPS: 1000
        });

        deploy(founderParamsArr, tokenParams, auctionParams, govParams);
    }

    function deploy(
        IManager.FounderParams[] memory _founderParams,
        IManager.TokenParams memory _tokenParams,
        IManager.AuctionParams memory _auctionParams,
        IManager.GovParams memory _govParams
    ) public {
        (address _token, address _metadata, address _auction, address _timelock, address _governor) = manager.deploy(
            _founderParams,
            _tokenParams,
            _auctionParams,
            _govParams
        );

        token = Token(_token);
        metadataRenderer = MetadataRenderer(_metadata);
        auction = Auction(_auction);
        timelock = Timelock(payable(_timelock));
        governor = Governor(_governor);

        vm.label(address(token), "TOKEN");
        vm.label(address(metadataRenderer), "METADATA_RENDERER");
        vm.label(address(auction), "AUCTION");
        vm.label(address(timelock), "TIMELOCK");
        vm.label(address(governor), "GOVERNOR");
    }
}
