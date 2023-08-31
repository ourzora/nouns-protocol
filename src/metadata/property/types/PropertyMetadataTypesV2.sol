// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title PropertyMetadataTypesV2
/// @author Iain Nash & Rohan Kulkarni
/// @notice The Metadata Renderer custom data types
interface PropertyMetadataTypesV2 {
    struct AdditionalTokenProperty {
        string key;
        string value;
        bool quote;
    }
}
