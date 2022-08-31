// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import { Test } from "forge-std/Test.sol";

import { IManager, Manager } from "../../src/manager/Manager.sol";
import { IToken, Token } from "../../src/token/Token.sol";
import { MetadataRenderer } from "../../src/token/metadata/MetadataRenderer.sol";
import { IAuction, Auction } from "../../src/auction/Auction.sol";
import { IGovernor, Governor } from "../../src/governance/governor/Governor.sol";
import { ITreasury, Treasury } from "../../src/governance/treasury/Treasury.sol";

import { ERC1967Proxy } from "../../src/lib/proxy/ERC1967Proxy.sol";
import { WETH } from ".././utils/WETH.sol";

import { MockERC721 } from "../utils/mocks/MockERC721.sol";
import { MockERC1155 } from "../utils/mocks/MockERC1155.sol";

contract NounsBuilderTest is Test {
    ///                                                          ///
    ///                          BASE SETUP                      ///
    ///                                                          ///

    Manager internal manager;

    address internal managerImpl0;
    address internal managerImpl;

    address internal tokenImpl;
    address internal metadataRendererImpl;
    address internal auctionImpl;
    address internal treasuryImpl;
    address internal governorImpl;

    address internal nounsDAO;
    address internal zoraDAO;
    address internal builderDAO;

    address internal founder;
    address internal founder2;
    address internal weth;

    MockERC721 internal mock721;
    MockERC1155 internal mock1155;

    function setUp() public virtual {
        weth = address(new WETH());

        mock721 = new MockERC721();
        mock1155 = new MockERC1155();

        nounsDAO = vm.addr(0xA11CE);
        zoraDAO = vm.addr(0xB0B);

        founder = vm.addr(0xCAB);
        founder2 = vm.addr(0xDAD);

        builderDAO = vm.addr(0xB3D);

        vm.label(zoraDAO, "ZORA_DAO");
        vm.label(nounsDAO, "NOUNS_DAO");
        vm.label(founder, "FOUNDER");
        vm.label(builderDAO, "BUILDER_DAO");

        //
        managerImpl0 = address(new Manager(address(0), address(0), address(0), address(0), address(0)));
        manager = Manager(address(new ERC1967Proxy(managerImpl0, abi.encodeWithSignature("initialize(address)", builderDAO))));

        tokenImpl = address(new Token(address(manager)));
        metadataRendererImpl = address(new MetadataRenderer(address(manager)));
        treasuryImpl = address(new Treasury(address(manager)));
        governorImpl = address(new Governor(address(manager)));
        auctionImpl = address(new Auction(address(manager), weth));

        managerImpl = address(new Manager(tokenImpl, metadataRendererImpl, auctionImpl, treasuryImpl, governorImpl));

        vm.prank(builderDAO);
        manager.upgradeTo(managerImpl);
    }

    ///                                                          ///
    ///                          DEPLOY UTILS                    ///
    ///                                                          ///

    bytes internal tokenInitStrings;

    IManager.FounderParams[] internal founderParamsArr;
    IManager.TokenParams internal tokenParams;
    IManager.AuctionParams internal auctionParams;
    IManager.GovParams internal govParams;

    Token internal token;
    MetadataRenderer internal metadataRenderer;
    Auction internal auction;
    Treasury internal treasury;
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

        founderParamsArr[0] = IManager.FounderParams({ wallet: founder, percentage: 10, vestingEnd: 4 weeks });
        founderParamsArr[1] = IManager.FounderParams({ wallet: founder2, percentage: 20, vestingEnd: 4 weeks });

        tokenParams = IManager.TokenParams({ initStrings: tokenInitStrings });
        auctionParams = IManager.AuctionParams({ reservePrice: 0.01 ether, duration: 10 minutes });

        govParams = IManager.GovParams({
            timelockDelay: 2 days,
            votingDelay: 1,
            votingPeriod: 1 days,
            proposalThresholdBps: 50,
            quorumThresholdBps: 1000
        });

        deploy(founderParamsArr, tokenParams, auctionParams, govParams);
    }

    function deploy(
        IManager.FounderParams[] memory _founderParams,
        IManager.TokenParams memory _tokenParams,
        IManager.AuctionParams memory _auctionParams,
        IManager.GovParams memory _govParams
    ) public {
        (address _token, address _metadata, address _auction, address _treasury, address _governor) = manager.deploy(
            _founderParams,
            _tokenParams,
            _auctionParams,
            _govParams
        );

        token = Token(_token);
        metadataRenderer = MetadataRenderer(_metadata);
        auction = Auction(_auction);
        treasury = Treasury(payable(_treasury));
        governor = Governor(_governor);

        vm.label(address(token), "TOKEN");
        vm.label(address(metadataRenderer), "METADATA_RENDERER");
        vm.label(address(auction), "AUCTION");
        vm.label(address(treasury), "TREASURY");
        vm.label(address(governor), "GOVERNOR");
    }

    ///                                                          ///
    ///                           USER UTILS                     ///
    ///                                                          ///

    address[] internal users;

    function createUsers(uint256 _numUsers) internal {
        users = new address[](_numUsers + 1);

        for (uint256 i = 1; i <= _numUsers; ++i) {
            address user = vm.addr(i);

            vm.deal(user, i);

            users[i] = user;
        }
    }
}
