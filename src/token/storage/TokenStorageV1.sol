// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {IMetadataRenderer} from "../metadata/IMetadataRenderer.sol";
import {TokenTypesV1} from "../types/TokenTypesV1.sol";

contract TokenStorageV1 is TokenTypesV1 {
    /// @notice The metadata renderer of the token
    IMetadataRenderer public metadataRenderer;

    /// @notice The minter of the token
    address public auction;

    /// @notice The total number of tokens minted
    uint256 public totalSupply;

    /// @notice The founders DAO allocation
    Founder[] public founders;
}
