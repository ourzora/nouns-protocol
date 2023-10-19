// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { IBaseToken } from "../interfaces/IBaseToken.sol";
import { IManager } from "../../manager/IManager.sol";

/// @title IToken
/// @author Rohan Kulkarni
/// @notice The external Token events, errors and functions
interface IToken is IBaseToken {
    ///                                                          ///
    ///                           FUNCTIONS                      ///
    ///                                                          ///

    /// @notice Initializes a DAO's ERC-721 token contract
    /// @param founders The DAO founders
    /// @param initStrings The encoded token and metadata initialization strings
    /// @param reservedUntilTokenId The tokenId that a DAO's auctions will start at
    /// @param metadataRenderer The token's metadata renderer
    /// @param auction The token's auction house
    /// @param initialOwner The initial owner of the token
    function initialize(
        IManager.FounderParams[] calldata founders,
        bytes calldata initStrings,
        uint256 reservedUntilTokenId,
        address metadataRenderer,
        address auction,
        address initialOwner
    ) external;
}
