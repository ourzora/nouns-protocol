// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { IUUPS } from "../../lib/interfaces/IUUPS.sol";

/// @title IBaseMetadata
/// @author Rohan Kulkarni
/// @notice The external Base Metadata errors and functions
interface IBaseMetadata is IUUPS {
    ///                                                          ///
    ///                            ERRORS                        ///
    ///                                                          ///

    /// @dev Reverts if the caller was not the contract manager
    error ONLY_MANAGER();

    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    /// @notice Emitted when the contract image is updated
    event ContractImageUpdated(string prevImage, string newImage);

    /// @notice Emitted when the collection description is updated
    event DescriptionUpdated(string prevDescription, string newDescription);

    /// @notice Emitted when the collection uri is updated
    event WebsiteURIUpdated(string lastURI, string newURI);

    ///                                                          ///
    ///                           FUNCTIONS                      ///
    ///                                                          ///

    /// @notice Initializes a DAO's token metadata renderer
    /// @param data The encoded token and metadata initialization strings
    /// @param token The associated ERC-721 token address
    function initialize(bytes calldata data, address token) external;

    /// @notice Generates attributes for a token upon mint
    /// @param tokenId The ERC-721 token id
    function onMinted(uint256 tokenId) external returns (bool);

    /// @notice The token URI
    /// @param tokenId The ERC-721 token id
    function tokenURI(uint256 tokenId) external view returns (string memory);

    /// @notice The token data
    /// @param tokenId The ERC-721 token id
    function tokenData(uint256 tokenId)
        external
        view
        returns (
            string memory name,
            string memory imageURI,
            string memory contentURI
        );

    /// @notice The contract URI
    function contractURI() external view returns (string memory);

    /// @notice The associated ERC-721 token
    function token() external view returns (address);

    /// @notice Get metadata owner address
    function owner() external view returns (address);

    /// @notice The contract image
    function contractImage() external view returns (string memory);

    /// @notice The collection description
    function description() external view returns (string memory);

    /// @notice The collection uri
    function projectURI() external view returns (string memory);

    /// @notice Updates the contract image
    /// @param newContractImage The new contract image
    function updateContractImage(string memory newContractImage) external;

    /// @notice Updates the collection description
    /// @param newDescription The new description
    function updateDescription(string memory newDescription) external;
}
