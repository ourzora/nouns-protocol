// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { IERC721 } from "../lib/interfaces/IERC721.sol";
import { IBaseToken } from "../token/interfaces/IBaseToken.sol";
import { IManager } from "../manager/IManager.sol";
import { IOwnable } from "../lib/interfaces/IOwnable.sol";
import { IMintStrategy } from "./interfaces/IMintStrategy.sol";

/// @title ERC721RedeemMinter
/// @notice A mint strategy that allows ERC721 token holders to redeem DAO tokens
/// @author @neokry
contract ERC721RedeemMinter is IMintStrategy {
    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    /// @notice Event for mint settings updated
    event MinterSet(address indexed tokenContract, RedeemSettings redeemSettings);

    ///                                                          ///
    ///                            ERRORS                        ///
    ///                                                          ///

    /// @dev Caller is not the owner of the specified token contract
    error NOT_TOKEN_OWNER();

    /// @dev Transfer failed
    error TRANSFER_FAILED();

    /// @dev Mint has ended
    error MINT_ENDED();

    /// @dev Mint has not started
    error MINT_NOT_STARTED();

    /// @dev Value sent does not match total fee value
    error INVALID_VALUE();

    /// @dev Invalid amount of tokens to claim
    error INVALID_TOKEN_COUNT();

    /// @dev Redeem token has not been minted yet
    error NOT_MINTED();

    ///                                                          ///
    ///                            STRUCTS                       ///
    ///                                                          ///

    /// @notice General redeem plus settings
    struct RedeemSettings {
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

    /// @notice Address to send BuilderDAO fees
    address immutable builderFundsRecipent;

    ///                                                          ///
    ///                            STORAGE                       ///
    ///                                                          ///

    /// @notice Stores the redeem settings for a token
    mapping(address => RedeemSettings) public redeemSettings;

    ///                                                          ///
    ///                            MODIFIERS                     ///
    ///                                                          ///

    /// @notice Checks if the caller is the token contract or the owner of the token contract
    /// @param tokenContract Token contract to check
    modifier onlyTokenOwner(address tokenContract) {
        // Revert if sender is not the token contract owner
        if (!_isContractOwner(msg.sender, tokenContract)) {
            revert NOT_TOKEN_OWNER();
        }
        _;
    }

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    constructor(IManager _manager, address _builderFundsRecipent) {
        manager = _manager;
        builderFundsRecipent = _builderFundsRecipent;
    }

    ///                                                          ///
    ///                            MINT                          ///
    ///                                                          ///

    /// @notice gets the total fees for minting
    function getTotalFeesForMint(address tokenContract, uint256 quantity) public view returns (uint256) {
        return _getTotalFeesForMint(redeemSettings[tokenContract].pricePerToken, quantity);
    }

    /// @notice mints a token from reserve using the collection plus strategy
    /// @notice mints a token from reserve using the collection plus strategy and sets delegations
    /// @param tokenContract The DAO token contract to mint from
    /// @param tokenIds List of tokenIds to redeem
    function mintFromReserve(address tokenContract, uint256[] calldata tokenIds) public payable {
        // Load settings from storage
        RedeemSettings memory settings = redeemSettings[tokenContract];

        // Cache token count
        uint256 tokenCount = tokenIds.length;

        // Validate params
        _validateParams(settings, tokenCount);

        unchecked {
            for (uint256 i = 0; i < tokenCount; ++i) {
                uint256 tokenId = tokenIds[i];

                // Check ownership of redeem token
                address owner = _ownerOfRedeemToken(settings.redeemToken, tokenId);

                // Cannot redeem a token that has not been minted
                if (owner == address(0)) {
                    revert NOT_MINTED();
                }

                // Mint to the redeeem token owner
                IBaseToken(tokenContract).mintFromReserveTo(owner, tokenId);
            }
        }

        // Distribute fees if minting fees for this collection are set (Builder DAO fee does not apply to free mints)
        if (settings.pricePerToken > 0) {
            _distributeFees(tokenContract, tokenCount);
        }
    }

    function _validateParams(RedeemSettings memory settings, uint256 tokenCount) internal {
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

    function _ownerOfRedeemToken(address redeemToken, uint256 tokenId) internal view returns (address) {
        // Check redeem token owner or return address(0) if it doesn't exist
        try IERC721(redeemToken).ownerOf(tokenId) returns (address redeemOwner) {
            return redeemOwner;
        } catch {
            return address(0);
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

        // Revert if Builder DAO recipent cannot accept funds
        if (!builderSuccess) {
            revert TRANSFER_FAILED();
        }

        // Pay out remaining funds to the treasury
        if (value > builderFee) {
            (bool treasurySuccess, ) = treasury.call{ value: value - builderFee }("");

            // Revert if treasury cannot accept funds
            if (!builderSuccess || !treasurySuccess) {
                revert TRANSFER_FAILED();
            }
        }
    }

    ///                                                          ///
    ///                            SETTINGS                      ///
    ///                                                          ///

    // @notice Sets the minter settings from the token contract with generic data
    /// @param data Encoded settings to set
    function setMintSettings(bytes calldata data) external {
        // Decode settings data
        RedeemSettings memory settings = abi.decode(data, (RedeemSettings));

        // Cache sender
        address sender = msg.sender;

        // Set new collection settings
        _setMintSettings(sender, settings);

        // Emit event for new settings
        emit MinterSet(sender, settings);
    }

    /// @notice Sets the minter settings for a token
    /// @param tokenContract Token contract to set settings for
    /// @param settings Settings to set
    function setMintSettings(address tokenContract, RedeemSettings memory settings) external onlyTokenOwner(tokenContract) {
        // Set new collection settings
        _setMintSettings(tokenContract, settings);

        // Emit event for new settings
        emit MinterSet(tokenContract, settings);
    }

    /// @notice Resets the minter settings for a token
    /// @param tokenContract Token contract to reset settings for
    function resetMintSettings(address tokenContract) external onlyTokenOwner(tokenContract) {
        // Reset collection settings to null
        delete redeemSettings[tokenContract];

        // Emit event with null settings
        emit MinterSet(tokenContract, redeemSettings[tokenContract]);
    }

    function _setMintSettings(address tokenContract, RedeemSettings memory settings) internal {
        redeemSettings[tokenContract] = settings;
    }

    function _isContractOwner(address caller, address tokenContract) internal view returns (bool) {
        return IOwnable(tokenContract).owner() == caller;
    }
}
