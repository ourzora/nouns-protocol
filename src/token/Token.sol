// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {UUPS} from "../lib/proxy/UUPS.sol";
import {Ownable} from "../lib/utils/Ownable.sol";
import {ReentrancyGuard} from "../lib/utils/ReentrancyGuard.sol";
import {ERC721Votes} from "../lib/token/ERC721Votes.sol";

import {TokenStorageV1} from "./storage/TokenStorageV1.sol";
import {INounsMetadata} from "./metadata/INounsMetadata.sol";
import {IManager} from "../manager/IManager.sol";
import {IToken} from "./IToken.sol";

/// @title Token
/// @author Rohan Kulkarni
/// @notice A DAO's ERC-721 token contract
contract Token is IToken, UUPS, ReentrancyGuard, ERC721Votes, TokenStorageV1 {
    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IManager private immutable manager;

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    /// @param _manager The address of the contract upgrade manager
    constructor(address _manager) payable initializer {
        manager = IManager(_manager);
    }

    ///                                                          ///
    ///                          INITIALIZER                     ///
    ///                                                          ///

    /// @notice Initializes an instance of a DAO's ERC-721 token
    /// @param _founders The members of the DAO with scheduled token allocations
    /// @param _initStrings The encoded token and metadata initialization strings
    /// @param _metadataRenderer The token's metadata renderer
    /// @param _auction The token's auction house
    function initialize(
        IManager.FounderParams[] calldata _founders,
        bytes calldata _initStrings,
        address _metadataRenderer,
        address _auction
    ) external initializer {
        // Initialize the reentrancy guard
        __ReentrancyGuard_init();

        // Store the vesting schedules of each founder
        _storeFounders(_founders);

        // Get the token name and symbol from the encoded strings
        (string memory _name, string memory _symbol, , , ) = abi.decode(_initStrings, (string, string, string, string, string));

        // Initialize the ERC-721 token
        __ERC721_init(_name, _symbol);

        // Store the associated auction house
        auction = _auction;

        // Store the associated metadata renderer
        metadataRenderer = INounsMetadata(_metadataRenderer);
    }

    ///                                                          ///
    ///                              MINT                        ///
    ///                                                          ///

    /// @notice Mints tokens to the auction house for bidding and handles vesting to the founders & Builder DAO
    function mint() public nonReentrant returns (uint256 tokenId) {
        // Ensure the caller is the auction house
        if (msg.sender != auction) revert ONLY_AUCTION();

        // Cannot realistically overflow
        unchecked {
            do {
                // Get the next available token id
                tokenId = totalSupply++;

                // While the current token id is elig
            } while (_isVest(tokenId));
        }

        // Mint the next token to the auction house for bidding
        _mint(auction, tokenId);

        return tokenId;
    }

    /// @dev Overrides _mint to include attribute generation
    /// @param _to The token recipient
    /// @param _tokenId The ERC-721 token id
    function _mint(address _to, uint256 _tokenId) internal override {
        // Mint the token
        super._mint(_to, _tokenId);

        // Generate the token attributes
        if (!metadataRenderer.onMinted(_tokenId)) {
            revert NO_METADATA_GENERATED();
        }
    }

    ///                                                          ///
    ///                           VESTING                        ///
    ///                                                          ///

    /// @dev Checks if a token is elgible to vest, and mints to the recipient if so
    /// @param _tokenId The ERC-721 token id
    function _isVest(uint256 _tokenId) private returns (bool) {
        // Cache the number of founders
        uint256 numFounders = founders.length;

        // Cannot realistically overflow
        unchecked {
            // For each founder:
            for (uint256 i; i < numFounders; ++i) {
                // Get their vesting details
                Founder memory founder = founders[i];

                // If the token id fits their vesting schedule:
                if (_tokenId % founder.allocationFrequency == 0 && block.timestamp < founder.vestingEnd) {
                    // Mint the token to the founder
                    _mint(founder.wallet, _tokenId);

                    return true;
                }
            }

            return false;
        }
    }

    /// @dev Stores the vesting details of the DAO's founders
    /// @param _founders The list of founders provided upon deploy
    function _storeFounders(IManager.FounderParams[] calldata _founders) internal {
        // Cache the number of founders
        uint256 numFounders = _founders.length;

        // Cannot realistically overflow
        unchecked {
            // For each founder:
            for (uint256 i; i < numFounders; ++i) {
                // Allocate storage space
                founders.push();

                // Get the storage location
                Founder storage founder = founders[i];

                // Store the given details
                founder.allocationFrequency = uint32(_founders[i].allocationFrequency);
                founder.vestingEnd = uint64(_founders[i].vestingEnd);
                founder.wallet = _founders[i].wallet;
            }
        }
    }

    ///                                                          ///
    ///                             BURN                         ///
    ///                                                          ///

    /// @notice Burns a token that did not see any bids
    /// @param _tokenId The ERC-721 token id
    function burn(uint256 _tokenId) public {
        // Ensure the caller is the auction house
        if (msg.sender != auction) revert ONLY_AUCTION();

        // Burn the token
        _burn(_tokenId);
    }

    ///                                                          ///
    ///                              URI                         ///
    ///                                                          ///

    /// @notice The URI for a given token
    /// @param _tokenId The ERC-721 token id
    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        return metadataRenderer.tokenURI(_tokenId);
    }

    /// @notice The URI for the contract
    function contractURI() public view override returns (string memory) {
        return metadataRenderer.contractURI();
    }

    ///                                                          ///
    ///                             OWNER                        ///
    ///                                                          ///

    /// @notice The shared owner of the token and metadata contracts
    function owner() public view returns (address) {
        return metadataRenderer.owner();
    }

    ///                                                          ///
    ///                        CONTRACT UPGRADE                  ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract and that the new implementation is valid
    /// @dev This function is called in `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The address of the new implementation
    function _authorizeUpgrade(address _newImpl) internal view override {
        // Ensure the caller is the shared owner of the token and metadata renderer
        if (msg.sender != owner()) revert ONLY_OWNER();

        // Ensure the implementation is valid
        if (!manager.isValidUpgrade(_getImplementation(), _newImpl)) revert INVALID_UPGRADE(_newImpl);
    }
}
