// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { IBuilderFeeManager } from "./interfaces/IBuilderFeeManager.sol";
import { Ownable } from "../lib/utils/Ownable.sol";

contract BuilderFeeManager is Ownable, IBuilderFeeManager {
    uint256 private defaultFeeBPS;

    event DefaultFeeSet(uint256 indexed);

    constructor(uint256 _defaultFeeBPS, address feeManagerAdmin) {
        defaultFeeBPS = _defaultFeeBPS;
        _transferOwnership(feeManagerAdmin);
    }

    function setDefaultFee(uint256 amountBPS) external onlyOwner {
        require(amountBPS < 2001, "Fee too high (not greater than 20%)");
        defaultFeeBPS = amountBPS;
        emit DefaultFeeSet(amountBPS);
    }

    function getBuilderFeesBPS() external view returns (address payable, uint256) {
        return (payable(owner()), defaultFeeBPS);
    }
}
