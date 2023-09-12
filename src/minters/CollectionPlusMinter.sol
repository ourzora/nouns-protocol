// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { IERC721 } from "../lib/interfaces/IERC721.sol";
import { IERC6551Registry } from "../lib/interfaces/IERC6551Registry.sol";
import { IPartialSoulboundToken } from "../token/partial-soulbound/IPartialSoulboundToken.sol";
import { IManager } from "../manager/IManager.sol";
import { IOwnable } from "../lib/interfaces/IOwnable.sol";

/// @title CollectionPlusMinter
/// @notice A mints and locks reserved tokens to ERC6551 accounts
/// @author @neokry
contract CollectionPlusMinter {
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

    /// @notice Event for mint settings updated
    event MinterSet(address indexed mediaContract, CollectionPlusSettings merkleSaleSettings);

    error NOT_TOKEN_OWNER();
    error NOT_MANAGER_OWNER();
    error TRANSFER_FAILED();
    error INVALID_OWNER();
    error MINT_ENDED();
    error MINT_NOT_STARTED();
    error INVALID_VALUE();

    /// @notice Per token mint fee sent to BuilderDAO
    uint256 public constant BUILDER_DAO_FEE = 0.000777 ether;

    /// @notice Manager contract
    IManager immutable manager;

    /// @notice ERC6551 registry
    IERC6551Registry immutable erc6551Registry;

    /// @notice Address to send BuilderDAO fees
    address immutable builderFundsRecipent;

    /// @notice Address of the ERC6551 implementation
    address immutable erc6551Impl;

    /// @notice Stores the collection plus settings for a token
    mapping(address => CollectionPlusSettings) public allowedCollections;

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

        address[] memory fromAddresses = new address[](tokenCount);

        unchecked {
            for (uint256 i = 0; i < tokenCount; ++i) {
                fromAddresses[i] = erc6551Registry.createAccount(erc6551Impl, block.chainid, settings.redeemToken, tokenIds[i], 0, initData);
                IPartialSoulboundToken(tokenContract).mintFromReserveAndLockTo(fromAddresses[i], tokenIds[i]);

                if (IERC721(settings.redeemToken).ownerOf(tokenIds[i]) != redeemFor) {
                    revert INVALID_OWNER();
                }
            }
        }

        IPartialSoulboundToken(tokenContract).batchDelegateBySigERC1271(fromAddresses, redeemFor, deadline, signature);

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
                address account = erc6551Registry.createAccount(erc6551Impl, block.chainid, settings.redeemToken, tokenIds[i], 0, initData);
                IPartialSoulboundToken(tokenContract).mintFromReserveAndLockTo(account, tokenIds[i]);

                if (IERC721(settings.redeemToken).ownerOf(tokenIds[i]) != redeemFor) {
                    revert INVALID_OWNER();
                }
            }
        }

        if (settings.pricePerToken > 0) {
            _distributeFees(tokenContract, tokenCount);
        }
    }

    /// @notice Sets the minter settings for a token
    /// @param tokenContract Token contract to set settings for
    /// @param collectionPlusSettings Settings to set
    function setSettings(address tokenContract, CollectionPlusSettings memory collectionPlusSettings) external {
        if (IOwnable(tokenContract).owner() != msg.sender) {
            revert NOT_TOKEN_OWNER();
        }

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

        delete allowedCollections[tokenContract];

        // Emit event with null settings
        emit MinterSet(tokenContract, allowedCollections[tokenContract]);
    }

    function _getTotalFeesForMint(uint256 pricePerToken, uint256 quantity) internal pure returns (uint256) {
        return pricePerToken > 0 ? quantity * (pricePerToken + BUILDER_DAO_FEE) : 0;
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

        if (msg.value < _getTotalFeesForMint(settings.pricePerToken, tokenCount)) {
            revert INVALID_VALUE();
        }
    }

    function _distributeFees(address tokenContract, uint256 quantity) internal {
        uint256 builderFee = quantity * BUILDER_DAO_FEE;
        uint256 value = msg.value;

        (, , address treasury, ) = manager.getAddresses(tokenContract);

        (bool builderSuccess, ) = builderFundsRecipent.call{ value: builderFee }("");
        if (!builderSuccess) {
            revert TRANSFER_FAILED();
        }

        if (value > builderFee) {
            (bool treasurySuccess, ) = treasury.call{ value: value - builderFee }("");

            if (!builderSuccess || !treasurySuccess) {
                revert TRANSFER_FAILED();
            }
        }
    }
}
