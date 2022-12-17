// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
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

contract DeployVersion1_1 is Script {
    using Strings for uint256;

    string configFile;

    function _getKey(string memory key) internal returns (address result) {
        (result) = abi.decode(vm.parseJson(configFile, key), (address));
    }

    function run() public {
        uint256 chainID = vm.envUint("CHAIN_ID");
        console.log("CHAIN_ID", chainID);
        uint256 key = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(key);

        configFile = vm.readFile(string.concat("./addresses/", Strings.toString(chainID), ".json"));

        address managerProxy = _getKey("Manager");
        address weth = _getKey("WETH");

        console2.log("~~~~~~~~~~ DEPLOYER ADDRESS ~~~~~~~~~~~");
        console2.logAddress(deployerAddress);

        console2.log("~~~~~~~~~~ MANAGER PROXY ~~~~~~~~~~~");
        console2.logAddress(managerProxy);

        console2.log("~~~~~~~~~~ WETH ADDRESS ~~~~~~~~~~~");
        console2.logAddress(weth);

        vm.startBroadcast(deployerAddress);

        // Get root manager implementation + proxy
        Manager manager = Manager(managerProxy);

        // Deploy auction upgrade implementation
        address auctionUpgradeImpl = address(new Auction(managerProxy, weth));
        // Deploy governor upgrade implementation
        address governorUpgradeImpl = address(new Governor(managerProxy));
        // Deploy treasury upgrade implementation
        address treasuryUpgradeImpl = address(new Treasury(managerProxy));
        // Deploy token upgrade implementation
        address tokenUpgradeImpl = address(new Token(managerProxy));
        // Deploy metadata upgrade implementation
        address metadataUpgradeImpl = address(new MetadataRenderer(managerProxy));

        address managerImpl = address(
            new Manager(tokenUpgradeImpl, metadataUpgradeImpl, auctionUpgradeImpl, treasuryUpgradeImpl, governorUpgradeImpl)
        );

        vm.stopBroadcast();

        string memory filePath = string(abi.encodePacked("deploys/", chainID.toString(), ".version1_1.txt"));
        vm.writeFile(filePath, "");
        vm.writeLine(filePath, string(abi.encodePacked("Auction Upgrade implementation: ", addressToString(auctionUpgradeImpl))));
        vm.writeLine(filePath, string(abi.encodePacked("Governor Upgrade implementation: ", addressToString(governorUpgradeImpl))));
        vm.writeLine(filePath, string(abi.encodePacked("Treasury Upgrade implementation: ", addressToString(treasuryUpgradeImpl))));
        vm.writeLine(filePath, string(abi.encodePacked("Token Upgrade implementation: ", addressToString(tokenUpgradeImpl))));
        vm.writeLine(filePath, string(abi.encodePacked("Metadata Upgrade implementation: ", addressToString(metadataUpgradeImpl))));
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
