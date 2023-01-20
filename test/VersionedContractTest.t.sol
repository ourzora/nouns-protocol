// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { NounsBuilderTest } from "./utils/NounsBuilderTest.sol";
import { VersionedContract } from "../src/VersionedContract.sol";

import "forge-std/console2.sol";

contract MockVersionedContract is VersionedContract {}

contract VersionedContractTest is NounsBuilderTest {
    string expectedVersion = "1.1.0";

    function test_Version() public {
        MockVersionedContract mockContract = new MockVersionedContract();
        // Update this test with each version
        assertEq(mockContract.contractVersion(), expectedVersion);
    }

    function test_VersionChildContracts() public {
        deployMock();

        assertEq(token.contractVersion(), expectedVersion);
        assertEq(metadataRenderer.contractVersion(), expectedVersion);
        assertEq(auction.contractVersion(), expectedVersion);
        assertEq(treasury.contractVersion(), expectedVersion);
        assertEq(governor.contractVersion(), expectedVersion);
    }

    function test_NPMPackageVersion() public {
        string memory packageVersion = abi.decode(vm.parseJson(vm.readFile("package.json"), "version"), (string));
        assertEq(packageVersion, expectedVersion);
    }
}
