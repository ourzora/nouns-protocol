// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {IGovernor} from "../IGovernor.sol";

/// @title Governor Storage V1
/// @author Rohan Kulkarni
/// @notice Modified version of NounsDAOInterfaces.sol (commit 2cbe6c7) that NounsDAO licensed under the GPL-3.0 license
contract GovernorStorageV1 {
    /// @notice The metadata of the governor
    IGovernor.GovMeta public govMeta;
}
