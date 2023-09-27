// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { IManager, Manager } from "../src/manager/Manager.sol";
import { PartialMirrorToken } from "../src/token/partial-mirror/PartialMirrorToken.sol";
import { ERC1967Proxy } from "../src/lib/proxy/ERC1967Proxy.sol";
import { ERC721RedeemMinter } from "../src/minters/ERC721RedeemMinter.sol";
import { MerkleReserveMinter } from "../src/minters/MerkleReserveMinter.sol";
import { MediaMetadata } from "../src/metadata/media/MediaMetadata.sol";

contract DeployContracts is Script {
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
        address managerAddress = _getKey("Manager");
        address builderDAO = _getKey("BuilderDAO");

        console2.log("~~~~~~~~~~ CHAIN ID ~~~~~~~~~~~");
        console2.log(chainID);

        console2.log("~~~~~~~~~~ DEPLOYER ~~~~~~~~~~~");
        console2.log(deployerAddress);

        console2.log("~~~~~~~~~~ MANAGER ~~~~~~~~~~~");
        console2.log(managerAddress);

        Manager manager = Manager(managerAddress);

        vm.startBroadcast(deployerAddress);

        address mirrorTokenImpl = address(new PartialMirrorToken(address(manager)));

        address erc721Minter = address(new ERC721RedeemMinter(manager, builderDAO));

        address merkleMinter = address(new MerkleReserveMinter(manager));

        address mediaMetadata = address(new MediaMetadata(address(manager)));

        // Register implementations
        manager.registerImplementation(manager.IMPLEMENTATION_TYPE_TOKEN(), mirrorTokenImpl);

        vm.stopBroadcast();

        string memory filePath = string(abi.encodePacked("deploys/", chainID.toString(), ".version2_new.txt"));

        vm.writeFile(filePath, "");
        vm.writeLine(filePath, string(abi.encodePacked("Mirror Token implementation: ", addressToString(mirrorTokenImpl))));
        vm.writeLine(filePath, string(abi.encodePacked("ERC721 Redeem Minter: ", addressToString(erc721Minter))));
        vm.writeLine(filePath, string(abi.encodePacked("Merkle Reserve Minter: ", addressToString(merkleMinter))));
        vm.writeLine(filePath, string(abi.encodePacked("Media Metadata Renderer: ", addressToString(mediaMetadata))));

        console2.log("~~~~~~~~~~ MIRROR TOKEN IMPL ~~~~~~~~~~~");
        console2.logAddress(mirrorTokenImpl);

        console2.log("~~~~~~~~~~ ERC721 REDEEM MINTER ~~~~~~~~~~~");
        console2.logAddress(erc721Minter);

        console2.log("~~~~~~~~~~ MERKLE RESERVE MINTER ~~~~~~~~~~~");
        console2.logAddress(merkleMinter);

        console2.log("~~~~~~~~~~ MEDIA METADATA RENDERER ~~~~~~~~~~~");
        console2.logAddress(mediaMetadata);
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
