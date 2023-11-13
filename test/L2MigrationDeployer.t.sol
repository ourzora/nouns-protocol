// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { NounsBuilderTest } from "./utils/NounsBuilderTest.sol";
import { MetadataRendererTypesV1 } from "../../src/token/metadata/types/MetadataRendererTypesV1.sol";
import { L2MigrationDeployer } from "../../src/deployers/L2MigrationDeployer.sol";
import { MerkleReserveMinter } from "../../src/minters/MerkleReserveMinter.sol";
import { MockCrossDomainMessenger } from "./utils/mocks/MockCrossDomainMessenger.sol";

import { IToken, Token } from "../../src/token/Token.sol";
import { MetadataRenderer } from "../../src/token/metadata/MetadataRenderer.sol";
import { IAuction, Auction } from "../../src/auction/Auction.sol";
import { IGovernor, Governor } from "../../src/governance/governor/Governor.sol";
import { ITreasury, Treasury } from "../../src/governance/treasury/Treasury.sol";

contract L2MigrationDeployerTest is NounsBuilderTest {
    MockCrossDomainMessenger xDomainMessenger;
    MerkleReserveMinter minter;
    L2MigrationDeployer deployer;
    MerkleReserveMinter.MerkleMinterSettings minterParams;

    function setUp() public virtual override {
        super.setUp();

        minter = new MerkleReserveMinter(address(manager), rewards);
        xDomainMessenger = new MockCrossDomainMessenger(founder);
        deployer = new L2MigrationDeployer(address(manager), address(minter), address(xDomainMessenger));
    }

    function deploy() internal {
        setAltMockFounderParams();

        setMockTokenParams();

        setMockAuctionParams();

        setMockGovParams();

        vm.startPrank(address(xDomainMessenger));

        address _token = deployer.deploy(foundersArr, tokenParams, auctionParams, govParams, minterParams);

        addMetadataProperties();

        deployer.renounceOwnership();

        vm.stopPrank();

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

    function addMetadataProperties() internal {
        string[] memory names = new string[](1);
        names[0] = "testing";
        MetadataRendererTypesV1.ItemParam[] memory items = new MetadataRendererTypesV1.ItemParam[](2);
        items[0] = MetadataRendererTypesV1.ItemParam({ propertyId: 0, name: "failure1", isNewProperty: true });
        items[1] = MetadataRendererTypesV1.ItemParam({ propertyId: 0, name: "failure2", isNewProperty: true });

        MetadataRendererTypesV1.IPFSGroup memory ipfsGroup = MetadataRendererTypesV1.IPFSGroup({ baseUri: "BASE_URI", extension: "EXTENSION" });

        bytes memory data = abi.encodeWithSignature("addProperties(string[],(uint256,string,bool)[],(string,string))", names, items, ipfsGroup);
        deployer.callMetadataRenderer(data);
    }

    function setMinterParams() internal {
        minterParams = MerkleReserveMinter.MerkleMinterSettings({
            mintStart: 200,
            mintEnd: uint64(block.timestamp + 1000),
            pricePerToken: 0.1 ether,
            merkleRoot: hex"00"
        });
    }

    function test_Deploy() external {
        deploy();
    }

    function test_MinterIsSet() external {
        deploy();

        assertTrue(token.isMinter(address(minter)));

        (uint64 mintStart, uint64 mintEnd, uint64 pricePerToken, bytes32 merkleRoot) = minter.allowedMerkles(address(token));

        assertEq(minterParams.mintStart, mintStart);
        assertEq(minterParams.mintEnd, mintEnd);
        assertEq(minterParams.pricePerToken, pricePerToken);
        assertEq(minterParams.merkleRoot, merkleRoot);
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

    function test_ResetDeployment() external {
        deploy();

        assertEq(deployer.crossDomainDeployerToToken(xDomainMessenger.xDomainMessageSender()), address(token));

        vm.prank(address(xDomainMessenger));
        deployer.resetDeployment();

        assertEq(deployer.crossDomainDeployerToToken(xDomainMessenger.xDomainMessageSender()), address(0));
    }

    function test_DepositToTreasury() external {
        deploy();

        vm.deal(address(xDomainMessenger), 0.1 ether);

        vm.prank(address(xDomainMessenger));
        deployer.depositToTreasury{ value: 0.1 ether }();

        assertEq(address(treasury).balance, 0.1 ether);
    }

    function testRevert_NoDAODeployed() external {
        vm.startPrank(address(xDomainMessenger));

        vm.expectRevert(abi.encodeWithSignature("NO_DAO_DEPLOYED()"));
        addMetadataProperties();

        vm.expectRevert(abi.encodeWithSignature("NO_DAO_DEPLOYED()"));
        deployer.renounceOwnership();

        vm.stopPrank();
    }

    function testRevert_DAOAlreadyDeployed() external {
        deploy();

        vm.prank(address(xDomainMessenger));
        vm.expectRevert(abi.encodeWithSignature("DAO_ALREADY_DEPLOYED()"));
        deployer.deploy(foundersArr, tokenParams, auctionParams, govParams, minterParams);
    }
}
