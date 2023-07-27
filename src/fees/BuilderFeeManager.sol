// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { IBuilderFeeManager } from "./interfaces/IBuilderFeeManager.sol";
import { Ownable } from "../lib/utils/Ownable.sol";

contract BuilderFeeManager is Ownable, IBuilderFeeManager {
    mapping(address => uint256) private feeOverride;
    uint256 private defaultFeeBPS;

    event FeeOverrideSet(address indexed, uint256 indexed);
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

    function setFeeOverride(address tokenContract, uint256 amountBPS) external onlyOwner {
        require(amountBPS < 2001, "Fee too high (not greater than 20%)");
        feeOverride[tokenContract] = amountBPS;
        emit FeeOverrideSet(tokenContract, amountBPS);
    }

    function getBuilderFeesBPS(address mediaContract) external view returns (address payable, uint256) {
        if (feeOverride[mediaContract] > 0) {
            return (payable(owner()), feeOverride[mediaContract]);
        }
        return (payable(owner()), defaultFeeBPS);
    }
}
