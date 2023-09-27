// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { IManager } from "../src/manager/IManager.sol";
import { IToken } from "../src/token/default/IToken.sol";
import { IPropertyMetadata } from "../src/metadata/property/interfaces/IPropertyMetadata.sol";
import { IAuction } from "../src/auction/IAuction.sol";
import { IGovernor } from "../src/governance/governor/IGovernor.sol";
import { ITreasury } from "../src/governance/treasury/ITreasury.sol";

contract SetupDaoScript is Script {
    using Strings for uint256;

    string configFile;

    function _getKey(string memory key) internal view returns (address result) {
        (result) = abi.decode(vm.parseJson(configFile, string.concat(".", key)), (address));
    }

    function run() public {
        uint256 chainID = vm.envUint("CHAIN_ID");
        uint256 key = vm.envUint("PRIVATE_KEY");

        configFile = vm.readFile(string.concat("./addresses/", Strings.toString(chainID), ".json"));

        address deployerAddress = vm.addr(key);

        console2.log("~~~~~~~~~~ CHAIN ID ~~~~~~~~~~~");
        console2.log(chainID);

        console2.log("~~~~~~~~~~ DEPLOYER ~~~~~~~~~~~");
        console2.log(deployerAddress);

        vm.startBroadcast(deployerAddress);

        IManager manager = IManager(_getKey("Manager"));

        IToken.TokenParams memory tokenParams = IToken.TokenParams({
            name: "Test",
            symbol: "TST",
            reservedUntilTokenId: 10,
            initalMinter: address(0),
            initalMinterData: hex"00"
        });

        IPropertyMetadata.PropertyMetadataParams memory metadataParams = IPropertyMetadata.PropertyMetadataParams({
            description: "This is a test DAO",
            contractImage: "https://test.com",
            projectURI: "https://test.com",
            rendererBase: "https://test.com"
        });

        IAuction.AuctionParams memory auctionParams = IAuction.AuctionParams({
            duration: 24 hours,
            reservePrice: 0.01 ether,
            founderRewardRecipent: address(0),
            founderRewardBPS: 0
        });

        IGovernor.GovParams memory govParams = IGovernor.GovParams({
            votingDelay: 2 days,
            votingPeriod: 2 days,
            proposalThresholdBps: 50,
            quorumThresholdBps: 1000,
            vetoer: address(0)
        });

        ITreasury.TreasuryParams memory treasuryParams = ITreasury.TreasuryParams({ timelockDelay: 2 days });

        IManager.FounderParams[] memory founders = new IManager.FounderParams[](1);
        founders[0] = IManager.FounderParams({ wallet: deployerAddress, ownershipPct: 10, vestExpiry: 30 days });

        address[] memory implementations = new address[](5);
        implementations[0] = _getKey("Token");
        implementations[1] = _getKey("MetadataRenderer");
        implementations[2] = _getKey("Auction");
        implementations[3] = _getKey("Treasury");
        implementations[4] = _getKey("Governor");

        bytes[] memory params = new bytes[](5);
        params[0] = abi.encode(tokenParams);
        params[1] = abi.encode(metadataParams);
        params[2] = abi.encode(auctionParams);
        params[3] = abi.encode(treasuryParams);
        params[4] = abi.encode(govParams);

        manager.deploy(founders, implementations, params);

        //now that we have a DAO process a proposal

        vm.stopBroadcast();
    }
}
