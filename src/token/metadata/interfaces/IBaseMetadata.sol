// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { IUUPS } from "../../../lib/interfaces/IUUPS.sol";
import { IOwnable } from "../../../lib/utils/Ownable.sol";

/// @title IBaseMetadata
/// @author Rohan Kulkarni
/// @notice The external Base Metadata errors and functions
interface IBaseMetadata is IUUPS, IOwnable {
    ///                                                          ///
    ///                            ERRORS                        ///
    ///                                                          ///

    /// @dev Reverts if the caller was not the contract manager
    error ONLY_MANAGER();

    ///                                                          ///
    ///                           FUNCTIONS                      ///
    ///                                                          ///

    /// @notice Initializes a DAO's token metadata renderer
    /// @param initStrings The encoded token and metadata initialization strings
    /// @param token The associated ERC-721 token address
    /// @param founder The founder address responsible for adding
    /// @param treasury The DAO treasury where ownership will be transferred
    function initialize(
        bytes calldata initStrings,
        address token,
        address founder,
        address treasury
    ) external;

    /// @notice Generates attributes for a token upon mint
    /// @param tokenId The ERC-721 token id
    function onMinted(uint256 tokenId) external returns (bool);

    /// @notice The token URI
    /// @param tokenId The ERC-721 token id
    function tokenURI(uint256 tokenId) external view returns (string memory);

    /// @notice The contract URI
    function contractURI() external view returns (string memory);

    /// @notice The associated ERC-721 token
    function token() external view returns (address);

    /// @notice The DAO treasury
    function treasury() external view returns (address);
}
