// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { Test } from "forge-std/Test.sol";

import { IManager, Manager } from "../../src/manager/Manager.sol";
import { IToken, Token } from "../../src/token/default/Token.sol";
import { IBaseMetadata, IPropertyMetadata, PropertyMetadata } from "../../src/metadata/property/PropertyMetadata.sol";
import { IAuction, Auction } from "../../src/auction/Auction.sol";
import { IGovernor, Governor } from "../../src/governance/governor/Governor.sol";
import { ITreasury, Treasury } from "../../src/governance/treasury/Treasury.sol";
import { PropertyMetadataTypesV1 } from "../../src/metadata/property/types/PropertyMetadataTypesV1.sol";

import { ERC1967Proxy } from "../../src/lib/proxy/ERC1967Proxy.sol";
import { MockERC721 } from "../utils/mocks/MockERC721.sol";
import { MockERC1155 } from "../utils/mocks/MockERC1155.sol";
import { WETH } from ".././utils/mocks/WETH.sol";
import { ProtocolRewards } from "../../src/rewards/ProtocolRewards.sol";

contract NounsBuilderTest is Test {
    ///                                                          ///
    ///                          BASE SETUP                      ///
    ///                                                          ///

    Manager internal manager;
    ProtocolRewards internal rewards;

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
        builderDAO = vm.addr(0xCAB);

        founder = vm.addr(0xDAD);
        founder2 = vm.addr(0xE1AD);

        vm.label(zoraDAO, "ZORA_DAO");
        vm.label(nounsDAO, "NOUNS_DAO");

        vm.label(founder, "FOUNDER");
        vm.label(founder2, "FOUNDER_2");

        managerImpl0 = address(new Manager());
        manager = Manager(address(new ERC1967Proxy(managerImpl0, abi.encodeWithSignature("initialize(address)", zoraDAO))));

        rewards = new ProtocolRewards(address(manager), builderDAO);

        tokenImpl = address(new Token(address(manager)));
        metadataRendererImpl = address(new PropertyMetadata(address(manager)));
        auctionImpl = address(new Auction(address(manager), address(rewards), weth));
        treasuryImpl = address(new Treasury(address(manager)));
        governorImpl = address(new Governor(address(manager)));

        managerImpl = address(new Manager());

        vm.startPrank(zoraDAO);
        manager.upgradeTo(managerImpl);
        manager.registerImplementation(manager.IMPLEMENTATION_TYPE_TOKEN(), tokenImpl);
        manager.registerImplementation(manager.IMPLEMENTATION_TYPE_METADATA(), metadataRendererImpl);
        manager.registerImplementation(manager.IMPLEMENTATION_TYPE_AUCTION(), auctionImpl);
        manager.registerImplementation(manager.IMPLEMENTATION_TYPE_TREASURY(), treasuryImpl);
        manager.registerImplementation(manager.IMPLEMENTATION_TYPE_GOVERNOR(), governorImpl);
        vm.stopPrank();
    }

    ///                                                          ///
    ///                     DAO CUSTOMIZATION UTILS              ///
    ///                                                          ///

    IManager.FounderParams[] internal foundersArr;
    IToken.TokenParams internal tokenParams;
    IPropertyMetadata.PropertyMetadataParams internal metadataParams;
    IAuction.AuctionParams internal auctionParams;
    IGovernor.GovParams internal govParams;
    ITreasury.TreasuryParams internal treasuryParams;

    address[] internal implAddresses;
    bytes[] internal implData;

    function setMockFounderParams() internal virtual {
        address[] memory wallets = new address[](2);
        uint256[] memory percents = new uint256[](2);
        uint256[] memory vestingEnds = new uint256[](2);

        wallets[0] = founder;
        wallets[1] = founder2;

        percents[0] = 10;
        percents[1] = 5;

        vestingEnds[0] = 4 weeks;
        vestingEnds[1] = 4 weeks;

        setFounderParams(wallets, percents, vestingEnds);
    }

    function setFounderParams(
        address[] memory _wallets,
        uint256[] memory _percents,
        uint256[] memory _vestingEnds
    ) internal virtual {
        uint256 numFounders = _wallets.length;

        require(numFounders == _percents.length && numFounders == _vestingEnds.length);

        unchecked {
            for (uint256 i; i < numFounders; ++i) {
                foundersArr.push();

                foundersArr[i] = IManager.FounderParams({ wallet: _wallets[i], ownershipPct: _percents[i], vestExpiry: _vestingEnds[i] });
            }
        }
    }

    function setMockTokenParams() internal virtual {
        setTokenParams(
            "Mock Token",
            "MOCK",
            "This is a mock token",
            "ipfs://Qmew7TdyGnj6YRUjQR68sUJN3239MYXRD8uxowxF6rGK8j",
            "https://nouns.build",
            "http://localhost:5000/render",
            0,
            address(0),
            new bytes(0)
        );
    }

    function setMockTokenParamsWithReserve(uint256 _reservedUntilTokenId) internal virtual {
        setTokenParams(
            "Mock Token",
            "MOCK",
            "This is a mock token",
            "ipfs://Qmew7TdyGnj6YRUjQR68sUJN3239MYXRD8uxowxF6rGK8j",
            "https://nouns.build",
            "http://localhost:5000/render",
            _reservedUntilTokenId,
            address(0),
            new bytes(0)
        );
    }

    function setMockTokenParamsWithReserveAndMinter(
        uint256 _reservedUntilTokenId,
        address minter,
        bytes memory minterData
    ) internal virtual {
        setTokenParams(
            "Mock Token",
            "MOCK",
            "This is a mock token",
            "ipfs://Qmew7TdyGnj6YRUjQR68sUJN3239MYXRD8uxowxF6rGK8j",
            "https://nouns.build",
            "http://localhost:5000/render",
            _reservedUntilTokenId,
            minter,
            minterData
        );
    }

    function setTokenParams(
        string memory _name,
        string memory _symbol,
        string memory _description,
        string memory _contractImage,
        string memory _contractURI,
        string memory _rendererBase,
        uint256 _reservedUntilTokenId,
        address _initalMinter,
        bytes memory _initalMinterData
    ) internal virtual {
        tokenParams = IToken.TokenParams({
            name: _name,
            symbol: _symbol,
            reservedUntilTokenId: _reservedUntilTokenId,
            initalMinter: _initalMinter,
            initalMinterData: _initalMinterData
        });
        metadataParams = IPropertyMetadata.PropertyMetadataParams({
            description: _description,
            contractImage: _contractImage,
            projectURI: _contractURI,
            rendererBase: _rendererBase
        });

        implData.push();
        implData[manager.IMPLEMENTATION_TYPE_TOKEN()] = abi.encode(tokenParams);

        implData.push();
        implData[manager.IMPLEMENTATION_TYPE_METADATA()] = abi.encode(metadataParams);
    }

    function setMockAuctionParams() internal virtual {
        setAuctionParams(0.01 ether, 10 minutes, address(0), 0);
    }

    function setAuctionParams(
        uint256 _reservePrice,
        uint256 _duration,
        address _founderRewardRecipent,
        uint256 _founderRewardBPS
    ) internal virtual {
        implData.push();
        auctionParams = IAuction.AuctionParams({
            reservePrice: _reservePrice,
            duration: _duration,
            founderRewardRecipent: _founderRewardRecipent,
            founderRewardBPS: _founderRewardBPS
        });
        implData[manager.IMPLEMENTATION_TYPE_AUCTION()] = abi.encode(auctionParams);
    }

    function setMockGovParams() internal virtual {
        setGovParams(2 days, 1 seconds, 1 weeks, 50, 1000, founder);
    }

    function setGovParams(
        uint256 _timelockDelay,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThresholdBps,
        uint256 _quorumThresholdBps,
        address _vetoer
    ) internal virtual {
        implData.push();
        treasuryParams = ITreasury.TreasuryParams({ timelockDelay: _timelockDelay });
        implData[manager.IMPLEMENTATION_TYPE_TREASURY()] = abi.encode(treasuryParams);

        implData.push();
        govParams = IGovernor.GovParams({
            votingDelay: _votingDelay,
            votingPeriod: _votingPeriod,
            proposalThresholdBps: _proposalThresholdBps,
            quorumThresholdBps: _quorumThresholdBps,
            vetoer: _vetoer
        });
        implData[manager.IMPLEMENTATION_TYPE_GOVERNOR()] = abi.encode(govParams);
    }

    function setMockMetadata() internal {
        string[] memory names = new string[](1);
        names[0] = "testing";

        PropertyMetadataTypesV1.ItemParam[] memory items = new PropertyMetadataTypesV1.ItemParam[](2);
        items[0] = PropertyMetadataTypesV1.ItemParam({ propertyId: 0, name: "failure1", isNewProperty: true });
        items[1] = PropertyMetadataTypesV1.ItemParam({ propertyId: 0, name: "failure2", isNewProperty: true });

        PropertyMetadataTypesV1.IPFSGroup memory ipfsGroup = PropertyMetadataTypesV1.IPFSGroup({ baseUri: "BASE_URI", extension: "EXTENSION" });

        vm.prank(metadataRenderer.owner());
        metadataRenderer.addProperties(names, items, ipfsGroup);
    }

    function setImplementationAddresses() internal {
        implAddresses.push();
        implAddresses[manager.IMPLEMENTATION_TYPE_TOKEN()] = tokenImpl;

        implAddresses.push();
        implAddresses[manager.IMPLEMENTATION_TYPE_METADATA()] = metadataRendererImpl;

        implAddresses.push();
        implAddresses[manager.IMPLEMENTATION_TYPE_AUCTION()] = auctionImpl;

        implAddresses.push();
        implAddresses[manager.IMPLEMENTATION_TYPE_TREASURY()] = treasuryImpl;

        implAddresses.push();
        implAddresses[manager.IMPLEMENTATION_TYPE_GOVERNOR()] = governorImpl;
    }

    ///                                                          ///
    ///                       DAO DEPLOY UTILS                   ///
    ///                                                          ///

    Token internal token;
    PropertyMetadata internal metadataRenderer;
    Auction internal auction;
    Treasury internal treasury;
    Governor internal governor;

    function deployMock() internal virtual {
        setMockFounderParams();

        setMockTokenParams();

        setMockAuctionParams();

        setMockGovParams();

        setImplementationAddresses();

        deploy(foundersArr, implAddresses, implData);

        setMockMetadata();
    }

    function deployWithCustomFounders(
        address[] memory _wallets,
        uint256[] memory _percents,
        uint256[] memory _vestExpirys
    ) internal virtual {
        setFounderParams(_wallets, _percents, _vestExpirys);

        setMockTokenParams();

        setMockAuctionParams();

        setMockGovParams();

        setImplementationAddresses();

        deploy(foundersArr, implAddresses, implData);

        setMockMetadata();
    }

    function deployWithCustomMetadata(
        string memory _name,
        string memory _symbol,
        string memory _description,
        string memory _contractImage,
        string memory _projectURI,
        string memory _rendererBase
    ) internal {
        setMockFounderParams();

        setTokenParams(_name, _symbol, _description, _contractImage, _projectURI, _rendererBase, 0, address(0), new bytes(0));

        setMockAuctionParams();

        setMockGovParams();

        setImplementationAddresses();

        deploy(foundersArr, implAddresses, implData);

        setMockMetadata();
    }

    function deployWithoutMetadata() internal {
        setMockFounderParams();

        setMockTokenParams();

        setMockAuctionParams();

        setMockGovParams();

        setImplementationAddresses();

        deploy(foundersArr, implAddresses, implData);
    }

    function deploy(
        IManager.FounderParams[] memory _founderParams,
        address[] memory _implAddresses,
        bytes[] memory _implData
    ) internal virtual {
        (address _token, address _metadata, address _auction, address _treasury, address _governor) = manager.deploy(
            _founderParams,
            _implAddresses,
            _implData
        );

        token = Token(_token);
        metadataRenderer = PropertyMetadata(_metadata);
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

    function createUser(uint256 _privateKey) internal virtual returns (address) {
        return vm.addr(_privateKey);
    }

    address[] internal otherUsers;

    function createUsers(uint256 _numUsers, uint256 _balance) internal virtual {
        otherUsers = new address[](_numUsers);

        unchecked {
            for (uint256 i; i < _numUsers; ++i) {
                address user = vm.addr(i + 1);

                vm.deal(user, _balance);

                otherUsers[i] = user;
            }
        }
    }

    function createTokens(uint256 _numTokens) internal {
        uint256 reservePrice = auction.reservePrice();
        uint256 duration = auction.duration();

        unchecked {
            for (uint256 i; i < _numTokens; ++i) {
                (uint256 tokenId, , , , , ) = auction.auction();

                vm.prank(otherUsers[i]);
                auction.createBid{ value: reservePrice }(tokenId);

                vm.warp(block.timestamp + duration);

                auction.settleCurrentAndCreateNewAuction();
            }
        }
    }

    function createVoters(uint256 _numVoters, uint256 _balance) internal {
        createUsers(_numVoters, _balance);

        createTokens(_numVoters);
    }
}
