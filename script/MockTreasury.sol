// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract MockTreasury {
    address owner;

    modifier onlyOwner() {
        require(owner == msg.sender, "Not owner");
        _;
    }

    constructor(address _owner) {
        owner = _owner;
    }

    function initialize(address govenor, uint256 timelockDelay) external {
        // do nothing
    }

    function execute(address target, bytes calldata data) public onlyOwner {
        target.call(data);
    }
}
