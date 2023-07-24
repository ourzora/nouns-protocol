// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { PropertyMetadataTypesV2 } from "../types/PropertyMetadataTypesV2.sol";

/// @title PropertyMetadataTypesV1
/// @author Iain Nash & Rohan Kulkarni
/// @notice The Metadata Renderer storage contract
contract PropertyMetadataStorageV2 is PropertyMetadataTypesV2 {
    /// @notice Additional JSON key/value properties for each token.
    /// @dev While strings are quoted, JSON needs to be escaped.
    AdditionalTokenProperty[] internal additionalTokenProperties;
}
