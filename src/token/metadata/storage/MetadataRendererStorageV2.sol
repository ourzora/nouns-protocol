// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { MetadataRendererTypesV2 } from "../types/MetadataRendererTypesV2.sol";

/// @title MetadataRendererTypesV1
/// @author Iain Nash & Rohan Kulkarni
/// @notice The Metadata Renderer storage contract
contract MetadataRendererStorageV2 is MetadataRendererTypesV2 {
    /// @notice Additional JSON key/value properties for each token.
    /// @dev While strings are quoted, JSON needs to be escaped.
    AdditionalTokenProperty[] internal additionalTokenProperties;
}
