// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { UUPS } from "../lib/proxy/UUPS.sol";
import { ReentrancyGuard } from "../lib/utils/ReentrancyGuard.sol";
import { ERC721Votes } from "../lib/token/ERC721Votes.sol";
import { ERC721 } from "../lib/token/ERC721.sol";

import { TokenStorageV1 } from "./storage/TokenStorageV1.sol";
import { IBaseMetadata } from "./metadata/interfaces/IBaseMetadata.sol";
import { IManager } from "../manager/IManager.sol";
import { IToken } from "./IToken.sol";

/// @title Token
/// @author Rohan Kulkarni
/// @notice A DAO's ERC-721 governance token
contract Token is IToken, UUPS, ReentrancyGuard, ERC721Votes, TokenStorageV1 {
    ///                                                          ///
    ///                         IMMUTABLES                       ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IManager private immutable manager;

    ///                                                          ///
    ///                         CONSTRUCTOR                      ///
    ///                                                          ///

    /// @param _manager The contract upgrade manager address
    constructor(address _manager) payable initializer {
        manager = IManager(_manager);
    }

    ///                                                          ///
    ///                         INITIALIZER                      ///
    ///                                                          ///

    /// @notice Initializes a DAO's ERC-721 token contract
    /// @param _founders The DAO founders
    /// @param _initStrings The encoded token and metadata initialization strings
    /// @param _metadataRenderer The token's metadata renderer
    /// @param _auction The token's auction house
    function initialize(
        IManager.FounderParams[] calldata _founders,
        bytes calldata _initStrings,
        address _metadataRenderer,
        address _auction
    ) external initializer {
        // Ensure the caller is the contract manager
        if (msg.sender != address(manager)) revert ONLY_MANAGER();

        // Initialize the reentrancy guard
        __ReentrancyGuard_init();

        // Store the founders and compute their allocations
        _addFounders(_founders);

        // Decode the token name and symbol
        (string memory _name, string memory _symbol, , , ) = abi.decode(_initStrings, (string, string, string, string, string));

        // Initialize the ERC-721 token
        __ERC721_init(_name, _symbol);

        // Store the metadata renderer and auction house
        settings.metadataRenderer = IBaseMetadata(_metadataRenderer);
        settings.auction = _auction;
    }

    /// @dev Called upon initialization to add founders and compute their vesting allocations
    /// @param _founders The list of DAO founders
    function _addFounders(IManager.FounderParams[] calldata _founders) internal {
        // Cache the number of founders
        uint256 numFounders = _founders.length;

        // Used to store the total percent ownership among the founders
        uint256 totalOwnership;

        unchecked {
            // For each founder:
            for (uint256 i; i < numFounders; ++i) {
                // Cache the percent ownership
                uint256 founderPct = _founders[i].ownershipPct;

                // Continue if no ownership is specified
                if (founderPct == 0) continue;

                // Update the total ownership and ensure it's valid
                if ((totalOwnership += uint8(founderPct)) > 100) revert INVALID_FOUNDER_OWNERSHIP();

                // Compute the founder's id
                uint256 founderId = settings.numFounders++;

                // Get the pointer to store the founder
                Founder storage newFounder = founder[founderId];

                // Store the founder's vesting details
                newFounder.wallet = _founders[i].wallet;
                newFounder.vestExpiry = uint32(_founders[i].vestExpiry);
                newFounder.ownershipPct = uint8(founderPct);

                // Compute the vesting schedule
                uint256 schedule = 100 / founderPct;

                // Used to store the base token id the founder will recieve
                uint256 baseTokenId;

                // For each token to vest:
                for (uint256 j; j < founderPct; ++j) {
                    // Get the available token id
                    baseTokenId = _getNextTokenId(baseTokenId);

                    // Store the founder as the recipient
                    tokenRecipient[baseTokenId] = newFounder;

                    emit MintScheduled(baseTokenId, founderId, newFounder);

                    // Update the base token id
                    (baseTokenId += schedule) % 100;
                }
            }

            // Store the founders' details
            settings.totalOwnership = uint8(totalOwnership);
            settings.numFounders = uint8(numFounders);
        }
    }

    /// @dev Finds the next available base token id for a founder
    /// @param _tokenId The ERC-721 token id
    function _getNextTokenId(uint256 _tokenId) internal view returns (uint256) {
        unchecked {
            while (tokenRecipient[_tokenId].wallet != address(0)) ++_tokenId;

            return _tokenId;
        }
    }

    ///                                                          ///
    ///                             MINT                         ///
    ///                                                          ///

    /// @notice Mints tokens to the auction house for bidding and handles founder vesting
    function mint() external nonReentrant returns (uint256 tokenId) {
        // Cache the auction address
        address minter = settings.auction;

        // Ensure the caller is the auction
        if (msg.sender != minter) revert ONLY_AUCTION();

        // Cannot realistically overflow
        unchecked {
            do {
                // Get the next token to mint
                tokenId = settings.totalSupply++;

                // Lookup whether the token is for a founder, and mint accordingly if so
            } while (_isForFounder(tokenId));
        }

        // Mint the next available token to the auction house for bidding
        _mint(minter, tokenId);
    }

    /// @dev Overrides _mint to include attribute generation
    /// @param _to The token recipient
    /// @param _tokenId The ERC-721 token id
    function _mint(address _to, uint256 _tokenId) internal override {
        // Mint the token
        super._mint(_to, _tokenId);

        // Generate the token attributes
        if (!settings.metadataRenderer.onMinted(_tokenId)) revert NO_METADATA_GENERATED();
    }

    /// @dev Checks if a given token is for a founder and mints accordingly
    /// @param _tokenId The ERC-721 token id
    function _isForFounder(uint256 _tokenId) private returns (bool) {
        // Get the base token id
        uint256 baseTokenId = _tokenId % 100;

        // If there is no scheduled recipient:
        if (tokenRecipient[baseTokenId].wallet == address(0)) {
            return false;

            // Else if the founder is still vesting:
        } else if (block.timestamp < tokenRecipient[baseTokenId].vestExpiry) {
            // Mint the token to the founder
            _mint(tokenRecipient[baseTokenId].wallet, _tokenId);

            return true;

            // Else the founder has finished vesting:
        } else {
            // Remove them from future lookups
            delete tokenRecipient[baseTokenId];

            return false;
        }
    }

    ///                                                          ///
    ///                             BURN                         ///
    ///                                                          ///

    /// @notice Burns a token that did not see any bids
    /// @param _tokenId The ERC-721 token id
    function burn(uint256 _tokenId) external {
        // Ensure the caller is the auction house
        if (msg.sender != settings.auction) revert ONLY_AUCTION();

        // Burn the token
        _burn(_tokenId);
    }

    ///                                                          ///
    ///                           METADATA                       ///
    ///                                                          ///

    /// @notice The URI for a token
    /// @param _tokenId The ERC-721 token id
    function tokenURI(uint256 _tokenId) public view override(IToken, ERC721) returns (string memory) {
        return settings.metadataRenderer.tokenURI(_tokenId);
    }

    /// @notice The URI for the contract
    function contractURI() public view override(IToken, ERC721) returns (string memory) {
        return settings.metadataRenderer.contractURI();
    }

    ///                                                          ///
    ///                           FOUNDERS                       ///
    ///                                                          ///

    /// @notice The number of founders
    function totalFounders() external view returns (uint256) {
        return settings.numFounders;
    }

    /// @notice The founders total percent ownership
    function totalFounderOwnership() external view returns (uint256) {
        return settings.totalOwnership;
    }

    /// @notice The vesting details of a founder
    /// @param _founderId The founder id
    function getFounder(uint256 _founderId) external view returns (Founder memory) {
        return founder[_founderId];
    }

    /// @notice The vesting details of all founders
    function getFounders() external view returns (Founder[] memory) {
        // Cache the number of founders
        uint256 numFounders = settings.numFounders;

        // Get a temporary array to hold all founders
        Founder[] memory founders = new Founder[](numFounders);

        // Cannot realistically overflow
        unchecked {
            // Add each founder to the array
            for (uint256 i; i < numFounders; ++i) founders[i] = founder[i];
        }

        return founders;
    }

    /// @notice The founder scheduled to receive the given token id
    /// NOTE: If a founder is returned, there's no guarantee they'll receive the token as vesting expiration is not considered
    /// @param _tokenId The ERC-721 token id
    function getScheduledRecipient(uint256 _tokenId) external view returns (Founder memory) {
        return tokenRecipient[_tokenId % 100];
    }

    ///                                                          ///
    ///                           SETTINGS                       ///
    ///                                                          ///

    /// @notice The total supply of tokens
    function totalSupply() external view returns (uint256) {
        return settings.totalSupply;
    }

    /// @notice The address of the auction house
    function auction() external view returns (address) {
        return settings.auction;
    }

    /// @notice The address of the metadata renderer
    function metadataRenderer() external view returns (address) {
        return address(settings.metadataRenderer);
    }

    /// @notice The address of the owner
    function owner() public view returns (address) {
        return settings.metadataRenderer.owner();
    }

    ///                                                          ///
    ///                         TOKEN UPGRADE                    ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract and that the new implementation is valid
    /// @dev This function is called in `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The new implementation address
    function _authorizeUpgrade(address _newImpl) internal view override {
        // Ensure the caller is the shared owner of the token and metadata renderer
        if (msg.sender != owner()) revert ONLY_OWNER();

        // Ensure the implementation is valid
        if (!manager.isRegisteredUpgrade(_getImplementation(), _newImpl)) revert INVALID_UPGRADE(_newImpl);
    }
}
