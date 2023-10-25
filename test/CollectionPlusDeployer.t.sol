// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { NounsBuilderTest } from "./utils/NounsBuilderTest.sol";
import { MetadataRendererTypesV1 } from "../../src/metadata/types/MetadataRendererTypesV1.sol";
import { CollectionPlusDeployer } from "../../src/deployers/CollectionPlusDeployer.sol";
import { ERC721RedeemMinter } from "../../src/minters/ERC721RedeemMinter.sol";

import { IToken, Token } from "../../src/token/default/Token.sol";
import { MetadataRenderer } from "../../src/metadata/MetadataRenderer.sol";
import { IAuction, Auction } from "../../src/auction/Auction.sol";
import { IGovernor, Governor } from "../../src/governance/governor/Governor.sol";
import { ITreasury, Treasury } from "../../src/governance/treasury/Treasury.sol";

contract CollectionPlusDeployerTest is NounsBuilderTest {
    ERC721RedeemMinter minter;
    CollectionPlusDeployer deployer;
    ERC721RedeemMinter.RedeemSettings minterParams;

    function setUp() public virtual override {
        super.setUp();

        minter = new ERC721RedeemMinter(manager, zoraDAO);
        deployer = new CollectionPlusDeployer(address(manager), address(minter));
    }

    function deploy() internal {
        setAltMockFounderParams();

        setMockMirrorTokenParams(0, address(0));

        setMockAuctionParams();

        setMockGovParams();

        getMetadataParams();

        CollectionPlusDeployer.MetadataParams memory metadataParams = getMetadataParams();

        address _token = deployer.deploy(foundersArr, mirrorTokenParams, auctionParams, govParams, metadataParams, minterParams);
        (address _metadata, address _auction, address _treasury, address _governor) = manager.getAddresses(_token);

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

    function setAltMockFounderParams() internal virtual {
        address[] memory wallets = new address[](3);
        uint256[] memory percents = new uint256[](3);
        uint256[] memory vestingEnds = new uint256[](3);

        wallets[0] = address(deployer);
        wallets[1] = founder;
        wallets[2] = founder2;

        percents[0] = 0;
        percents[1] = 10;
        percents[2] = 5;

        percents[0] = 0;
        vestingEnds[1] = 4 weeks;
        vestingEnds[2] = 4 weeks;

        setFounderParams(wallets, percents, vestingEnds);
    }

    function getMetadataParams() internal pure returns (CollectionPlusDeployer.MetadataParams memory metadataParams) {
        metadataParams.names = new string[](1);
        metadataParams.names[0] = "testing";
        metadataParams.items = new MetadataRendererTypesV1.ItemParam[](2);
        metadataParams.items[0] = MetadataRendererTypesV1.ItemParam({ propertyId: 0, name: "failure1", isNewProperty: true });
        metadataParams.items[1] = MetadataRendererTypesV1.ItemParam({ propertyId: 0, name: "failure2", isNewProperty: true });

        metadataParams.ipfsGroup = MetadataRendererTypesV1.IPFSGroup({ baseUri: "BASE_URI", extension: "EXTENSION" });
    }

    function setMinterParams() internal {
        minterParams = ERC721RedeemMinter.RedeemSettings({
            mintStart: 0,
            mintEnd: uint64(block.timestamp + 1000),
            pricePerToken: 0 ether,
            redeemToken: address(0)
        });
    }

    function test_Deploy() external {
        deploy();
    }

    function test_MinterIsSet() external {
        deploy();

        assertTrue(token.isMinter(address(minter)));

        (uint64 mintStart, uint64 mintEnd, uint64 pricePerToken, address redeemToken) = minter.redeemSettings(address(token));

        assertEq(minterParams.mintStart, mintStart);
        assertEq(minterParams.mintEnd, mintEnd);
        assertEq(minterParams.pricePerToken, pricePerToken);
        assertEq(minterParams.redeemToken, redeemToken);
    }

    function test_MetadataIsSet() external {
        deploy();

        assertGt(metadataRenderer.propertiesCount(), 0);
        assertGt(metadataRenderer.itemsCount(0), 0);
        assertGt(metadataRenderer.ipfsDataCount(), 0);
    }

    function test_FounderAreSet() external {
        deploy();

        IToken.Founder[] memory founders = token.getFounders();
        assertEq(founders.length, 2);
        assertEq(founders[0].wallet, founder);
        assertEq(founders[1].wallet, founder2);
    }

    function test_TreasuryIsOwner() external {
        deploy();

        assertEq(token.owner(), address(treasury));
        assertEq(metadataRenderer.owner(), address(treasury));
        assertEq(auction.owner(), address(treasury));
    }
}
