// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { IManager, Manager } from "../src/manager/Manager.sol";
import { IToken, Token } from "../src/token/Token.sol";
import { MetadataRenderer } from "../src/token/metadata/MetadataRenderer.sol";
import { IAuction, Auction } from "../src/auction/Auction.sol";
import { IGovernor, Governor } from "../src/governance/governor/Governor.sol";
import { ITreasury, Treasury } from "../src/governance/treasury/Treasury.sol";
import { MetadataRenderer } from "../src/token/metadata/MetadataRenderer.sol";
import { MetadataRendererTypesV1 } from "../src/token/metadata/types/MetadataRendererTypesV1.sol";
import { ERC1967Proxy } from "../src/lib/proxy/ERC1967Proxy.sol";

contract DeployMetadataUpgrade is Script {
    using Strings for uint256;

    function run() public {
        uint256 chainID = vm.envUint("CHAIN_ID");
        console.log("CHAIN_ID", chainID);
        uint256 key = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(key);
        address managerProxy = vm.envAddress("MANAGER_PROXY");
        address tokenImpl = vm.envAddress("TOKEN_IMPLEMENTATION");
        address auctionImpl = vm.envAddress("AUCTION_IMPLEMENTATION");
        address treasuryImpl = vm.envAddress("TREASURY_IMPLEMENTATION");
        address governorImpl = vm.envAddress("GOVERNOR_IMPLEMENTATION");

        console2.log("~~~~~~~~~~ DEPLOYER ADDRESS ~~~~~~~~~~~");
        console2.logAddress(deployerAddress);

        console2.log("~~~~~~~~~~ TOKEN IMPL ~~~~~~~~~~~");
        console2.logAddress(tokenImpl);

        console2.log("~~~~~~~~~~ MANAGER PROXY ~~~~~~~~~~~");
        console2.logAddress(managerProxy);

        console2.log("~~~~~~~~~~ AUCTION IMPL ~~~~~~~~~~~");
        console2.logAddress(auctionImpl);

        console2.log("~~~~~~~~~~ TREASURY IMPL ~~~~~~~~~~~");
        console2.logAddress(treasuryImpl);

        console2.log("~~~~~~~~~~ GOVERNOR IMPL ~~~~~~~~~~~");
        console2.logAddress(governorImpl);

        vm.startBroadcast(deployerAddress);

        // Deploy root manager implementation + proxy
        Manager manager = Manager(managerProxy);

        // Deploy metadata renderer implementation
        address metadataRendererImpl = address(new MetadataRenderer(managerProxy));

        address managerImpl = address(new Manager(tokenImpl, metadataRendererImpl, auctionImpl, treasuryImpl, governorImpl));

        console2.log("MR");
        console2.log(metadataRendererImpl);

        console2.log("M");
        console2.log(managerImpl);

        // console2.log("OWNER", manager.owner());

        // manager.upgradeTo(managerImpl);

        vm.stopBroadcast();

        string memory filePath = string(abi.encodePacked("deploys/", chainID.toString(), ".upgradeMetadata.txt"));
        vm.writeFile(filePath, "");
        vm.writeLine(filePath, string(abi.encodePacked("Metadata Renderer implementation: ", addressToString(metadataRendererImpl))));
        vm.writeLine(filePath, string(abi.encodePacked("Manager implementation: ", addressToString(managerImpl))));
    }

    function addressToString(address _addr) private pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint256(uint160(_addr)) / (2**(8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        return string(abi.encodePacked("0x", string(s)));
    }

    function char(bytes1 b) private pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }
}
