// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "forge-std/Test.sol";

contract TestUpdateOwners is Test {
  function test_UpdateOwners() public {
    address managerAddress = vm.envAddress("MANAGER_ADDRESS");

    Manager manager = Manager(managerAddress);

    // step 1 deploy new token
    Token newTokenImpl = new Token(managerAddress);

    vm.prank(manager.owner());
    manager.registerUpgrade(manager.tokenImpl(), newTokenImpl);

    // create dao

    // upgrade token

    // set new ownership params from governor

  }

}