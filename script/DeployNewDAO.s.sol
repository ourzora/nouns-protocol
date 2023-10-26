// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { IManager } from "../src/manager/IManager.sol";
import { IBaseMetadata } from "../src/token/metadata/interfaces/IBaseMetadata.sol";
import { IAuction } from "../src/auction/IAuction.sol";
import { IGovernor } from "../src/governance/governor/IGovernor.sol";
import { ITreasury } from "../src/governance/treasury/ITreasury.sol";
import { MerkleReserveMinter } from "../src/minters/MerkleReserveMinter.sol";

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

        bytes memory initStrings = abi.encode(
            "Test 999",
            "TST",
            "This is the desc",
            "https://contract-image.png",
            "https://project-uri.json",
            "https://renderer.com/render"
        );

        IManager.TokenParams memory tokenParams = IManager.TokenParams({
            initStrings: initStrings,
            metadataRenderer: address(0),
            reservedUntilTokenId: 10
        });

        IManager.AuctionParams memory auctionParams = IManager.AuctionParams({
            duration: 24 hours,
            reservePrice: 0.01 ether,
            founderRewardRecipent: address(0xB0B),
            founderRewardBps: 20
        });

        IManager.GovParams memory govParams = IManager.GovParams({
            votingDelay: 2 days,
            votingPeriod: 2 days,
            proposalThresholdBps: 50,
            quorumThresholdBps: 1000,
            vetoer: address(0),
            timelockDelay: 2 days
        });

        IManager.FounderParams[] memory founders = new IManager.FounderParams[](1);
        founders[0] = IManager.FounderParams({ wallet: deployerAddress, ownershipPct: 10, vestExpiry: 30 days });

        IManager manager = IManager(_getKey("Manager"));
        manager.deploy(founders, tokenParams, auctionParams, govParams);

        //now that we have a DAO process a proposal

        vm.stopBroadcast();
    }
}
