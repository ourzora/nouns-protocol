// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { IERC721 } from "../lib/interfaces/IERC721.sol";
import { IERC6551Registry } from "../lib/interfaces/IERC6551Registry.sol";
import { IPartialSoulboundToken } from "../token/partial-soulbound/IPartialSoulboundToken.sol";
import { IManager } from "../manager/IManager.sol";
import { IOwnable } from "../lib/interfaces/IOwnable.sol";

/// @title CollectionPlusMinter
/// @notice A mint strategy that mints and locks reserved tokens to ERC6551 accounts
/// @author @neokry
contract CollectionPlusMinter {
    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    /// @notice Event for mint settings updated
    event MinterSet(address indexed mediaContract, CollectionPlusSettings merkleSaleSettings);

    ///                                                          ///
    ///                            ERRORS                        ///
    ///                                                          ///

    /// @dev Caller is not the owner of the specified token contract
    error NOT_TOKEN_OWNER();

    /// @dev Caller is not the owner of the manager contract
    error NOT_MANAGER_OWNER();

    /// @dev Transfer failed
    error TRANSFER_FAILED();

    /// @dev Caller tried to claim a token with a mismatched owner
    error INVALID_OWNER();

    /// @dev Mint has ended
    error MINT_ENDED();

    /// @dev Mint has not started
    error MINT_NOT_STARTED();

    /// @dev Value sent does not match total fee value
    error INVALID_VALUE();

    /// @dev Invalid amount of tokens to claim
    error INVALID_TOKEN_COUNT();

    ///                                                          ///
    ///                            STRUCTS                       ///
    ///                                                          ///

    /// @notice General collection plus settings
    struct CollectionPlusSettings {
        /// @notice Unix timestamp for the mint start
        uint64 mintStart;
        /// @notice Unix timestamp for the mint end
        uint64 mintEnd;
        /// @notice Price per token
        uint64 pricePerToken;
        /// @notice Redemption token
        address redeemToken;
    }

    ///                                                          ///
    ///                            CONSTANTS                     ///
    ///                                                          ///

    /// @notice Per token mint fee sent to BuilderDAO
    uint256 public constant BUILDER_DAO_FEE = 0.000777 ether;

    ///                                                          ///
    ///                            IMMUTABLES                    ///
    ///                                                          ///

    /// @notice Manager contract
    IManager immutable manager;

    /// @notice ERC6551 registry
    IERC6551Registry immutable erc6551Registry;

    /// @notice Address to send BuilderDAO fees
    address immutable builderFundsRecipent;

    /// @notice Address of the ERC6551 implementation
    address immutable erc6551Impl;

    ///                                                          ///
    ///                            STORAGE                       ///
    ///                                                          ///

    /// @notice Stores the collection plus settings for a token
    mapping(address => CollectionPlusSettings) public allowedCollections;

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    constructor(
        IManager _manager,
        IERC6551Registry _erc6551Registry,
        address _erc6551Impl,
        address _builderFundsRecipent
    ) {
        manager = _manager;
        erc6551Registry = _erc6551Registry;
        builderFundsRecipent = _builderFundsRecipent;
        erc6551Impl = _erc6551Impl;
    }

    ///                                                          ///
    ///                            MINT                          ///
    ///                                                          ///

    /// @notice gets the total fees for minting
    function getTotalFeesForMint(address tokenContract, uint256 quantity) public view returns (uint256) {
        return _getTotalFeesForMint(allowedCollections[tokenContract].pricePerToken, quantity);
    }

    /// @notice mints a token from reserve using the collection plus strategy and sets delegations
    /// @param tokenContract The DAO token contract to mint from
    /// @param redeemFor Address to redeem tokens for
    /// @param tokenIds List of tokenIds to redeem
    /// @param initData ERC6551 account init data
    /// @param signature ERC1271 signature for delegation
    /// @param deadline Deadline for signature
    function mintFromReserveAndDelegate(
        address tokenContract,
        address redeemFor,
        uint256[] calldata tokenIds,
        bytes calldata initData,
        bytes calldata signature,
        uint256 deadline
    ) public payable {
        CollectionPlusSettings memory settings = allowedCollections[tokenContract];
        uint256 tokenCount = tokenIds.length;

        _validateParams(settings, tokenCount);

        // Keep track of the ERC6551 accounts for delegation step
        address[] memory fromAddresses = new address[](tokenCount);

        unchecked {
            for (uint256 i = 0; i < tokenCount; ++i) {
                // Create an ERC6551 account for the token. If an account already exists this function will return the existing account.
                fromAddresses[i] = erc6551Registry.createAccount(erc6551Impl, block.chainid, settings.redeemToken, tokenIds[i], 0, initData);

                // Locks the token to the ERC6551 account to tie DAO voting power to the original NFT token
                IPartialSoulboundToken(tokenContract).mintFromReserveAndLockTo(fromAddresses[i], tokenIds[i]);

                // We only want to allow batch claiming for one owner at a time
                if (IERC721(settings.redeemToken).ownerOf(tokenIds[i]) != redeemFor) {
                    revert INVALID_OWNER();
                }
            }
        }

        // Delegation must be setup after all tokens are transfered due to delegation resetting on transfer
        IPartialSoulboundToken(tokenContract).batchDelegateBySigERC1271(fromAddresses, redeemFor, deadline, signature);

        // Distribute fees if minting fees for this collection are set (Builder DAO fee does not apply to free mints)
        if (settings.pricePerToken > 0) {
            _distributeFees(tokenContract, tokenCount);
        }
    }

    /// @notice mints a token from reserve using the collection plus strategy
    /// @notice mints a token from reserve using the collection plus strategy and sets delegations
    /// @param tokenContract The DAO token contract to mint from
    /// @param redeemFor Address to redeem tokens for
    /// @param tokenIds List of tokenIds to redeem
    /// @param initData ERC6551 account init data
    function mintFromReserve(
        address tokenContract,
        address redeemFor,
        uint256[] calldata tokenIds,
        bytes calldata initData
    ) public payable {
        CollectionPlusSettings memory settings = allowedCollections[tokenContract];
        uint256 tokenCount = tokenIds.length;

        _validateParams(settings, tokenCount);

        unchecked {
            for (uint256 i = 0; i < tokenCount; ++i) {
                // Create an ERC6551 account for the token. If an account already exists this function will return the existing account.
                address account = erc6551Registry.createAccount(erc6551Impl, block.chainid, settings.redeemToken, tokenIds[i], 0, initData);

                // Locks the token to the ERC6551 account to tie DAO voting power to the original NFT token
                IPartialSoulboundToken(tokenContract).mintFromReserveAndLockTo(account, tokenIds[i]);

                // We only want to allow batch claiming for one owner at a time
                if (IERC721(settings.redeemToken).ownerOf(tokenIds[i]) != redeemFor) {
                    revert INVALID_OWNER();
                }
            }
        }

        // Distribute fees if minting fees for this collection are set (Builder DAO fee does not apply to free mints)
        if (settings.pricePerToken > 0) {
            _distributeFees(tokenContract, tokenCount);
        }
    }

    function _validateParams(CollectionPlusSettings memory settings, uint256 tokenCount) internal {
        // Check sale end
        if (block.timestamp > settings.mintEnd) {
            revert MINT_ENDED();
        }

        // Check sale start
        if (block.timestamp < settings.mintStart) {
            revert MINT_NOT_STARTED();
        }

        // Require at least one token claim
        if (tokenCount < 1) {
            revert INVALID_TOKEN_COUNT();
        }

        // Check value sent
        if (msg.value < _getTotalFeesForMint(settings.pricePerToken, tokenCount)) {
            revert INVALID_VALUE();
        }
    }

    ///                                                          ///
    ///                            FEES                          ///
    ///                                                          ///

    function _getTotalFeesForMint(uint256 pricePerToken, uint256 quantity) internal pure returns (uint256) {
        // If pricePerToken is 0 the mint has no Builder DAO fee
        return pricePerToken > 0 ? quantity * (pricePerToken + BUILDER_DAO_FEE) : 0;
    }

    function _distributeFees(address tokenContract, uint256 quantity) internal {
        uint256 builderFee = quantity * BUILDER_DAO_FEE;
        uint256 value = msg.value;

        (, , address treasury, ) = manager.getAddresses(tokenContract);

        // Pay out fees to the Builder DAO
        (bool builderSuccess, ) = builderFundsRecipent.call{ value: builderFee }("");

        // Sanity check: revert if Builder DAO recipent cannot accept funds
        if (!builderSuccess) {
            revert TRANSFER_FAILED();
        }

        // Pay out remaining funds to the treasury
        if (value > builderFee) {
            (bool treasurySuccess, ) = treasury.call{ value: value - builderFee }("");

            // Sanity check: revert if treasury cannot accept funds
            if (!builderSuccess || !treasurySuccess) {
                revert TRANSFER_FAILED();
            }
        }
    }

    ///                                                          ///
    ///                            SETTINGS                      ///
    ///                                                          ///

    /// @notice Sets the minter settings for a token
    /// @param tokenContract Token contract to set settings for
    /// @param collectionPlusSettings Settings to set
    function setSettings(address tokenContract, CollectionPlusSettings memory collectionPlusSettings) external {
        if (IOwnable(tokenContract).owner() != msg.sender) {
            revert NOT_TOKEN_OWNER();
        }

        // Set new collection settings
        allowedCollections[tokenContract] = collectionPlusSettings;

        // Emit event for new settings
        emit MinterSet(tokenContract, collectionPlusSettings);
    }

    /// @notice Resets the minter settings for a token
    /// @param tokenContract Token contract to reset settings for
    function resetSettings(address tokenContract) external {
        if (IOwnable(tokenContract).owner() != msg.sender) {
            revert NOT_TOKEN_OWNER();
        }

        // Reset collection settings to null
        delete allowedCollections[tokenContract];

        // Emit event with null settings
        emit MinterSet(tokenContract, allowedCollections[tokenContract]);
    }
}
