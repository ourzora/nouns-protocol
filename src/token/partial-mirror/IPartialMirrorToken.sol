// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { IUUPS } from "../../lib/interfaces/IUUPS.sol";
import { IERC721Votes } from "../../lib/interfaces/IERC721Votes.sol";
import { IManager } from "../../manager/IManager.sol";
import { IMirrorToken } from "../interfaces/IMirrorToken.sol";
import { IBaseToken } from "../interfaces/IBaseToken.sol";
import { IMirrorToken } from "../interfaces/IMirrorToken.sol";

/// @title IToken
/// @author Neokry
/// @notice The external Token events, errors and functions
interface IPartialMirrorToken is IBaseToken, IMirrorToken {
    ///                                                          ///
    ///                            ERRORS                        ///
    ///                                                          ///

    /// @dev Reverts if the token is already mirrored
    error ALREADY_MIRRORED();

    /// @dev Reverts if an approval function for a reserved token has been called
    error NO_APPROVALS();

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
        address tokenToMirror,
        address metadataRenderer,
        address auction,
        address initialOwner
    ) external;
}
