// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {UUPS} from "../lib/proxy/UUPS.sol";
import {Ownable} from "../lib/utils/Ownable.sol";
import {ReentrancyGuard} from "../lib/utils/ReentrancyGuard.sol";
import {ERC721Votes} from "../lib/token/ERC721Votes.sol";

import {TokenStorageV1} from "./storage/TokenStorageV1.sol";
import {MetadataRenderer} from "./metadata/MetadataRenderer.sol";
import {IMetadataRenderer} from "./metadata/IMetadataRenderer.sol";
import {IManager} from "../manager/IManager.sol";
import {IAuction} from "../auction/IAuction.sol";
import {IToken} from "./IToken.sol";

/// @title Token
/// @author Rohan Kulkarni
/// @notice A DAO's ERC-721 token contract
contract Token is Ownable, IToken, UUPS, ReentrancyGuard, ERC721Votes, TokenStorageV1 {
    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IManager private immutable manager;

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    /// @param _manager The address of the contract upgrade manager
    constructor(IManager _manager) payable initializer {
        manager = _manager;
    }

    modifier onlyFromAuction() {
        // Ensure the caller is the auction house
        (, IAuction auction, , ) = manager.getAddresses(address(this));
        if (msg.sender != address(auction)) {
            revert ONLY_AUCTION();
        }

        _;
    }

    function getMetadataRenderer() internal view returns (IMetadataRenderer) {
        // Get renderer address
        (IMetadataRenderer renderer, , ,) = manager.getAddresses(address(this));
        // return
        return renderer;
    }

    ///                                                          ///
    ///                          INITIALIZER                     ///
    ///                                                          ///

    /// @notice Initializes an instance of a DAO's ERC-721 token
    /// @param _founders The members of the DAO with scheduled token allocations
    /// @param _initStrings The encoded token and metadata initialization strings
    function initialize(
        IManager.FounderParams[] calldata _founders,
        address founder,
        bytes calldata _initStrings
    ) external initializer {
        // Initialize the reentrancy guard
        __ReentrancyGuard_init();

        // Store the vesting schedules of each founder
        _storeFounders(_founders);

        __Ownable_init(founder);

        // Get the token name and symbol from the encoded strings
        (string memory _name, string memory _symbol, , , ) = abi.decode(_initStrings, (string, string, string, string, string));

        // Initialize the ERC-721 token
        __ERC721_init(_name, _symbol);
    }

    ///                                                          ///
    ///                              MINT                        ///
    ///                                                          ///


    /// @notice Mints tokens to the auction house for bidding and handles vesting to the founders & Builder DAO
    function mint() public nonReentrant onlyFromAuction returns (uint256 tokenId) {
        // Cannot realistically overflow
        unchecked {
            do {
                // Get the next available token id
                tokenId = totalSupply++;

                // While the current token id is elig
            } while (_isVest(tokenId));
        }

        // Mint the next token to the auction house for bidding
        _mint(address(auction), tokenId);

        return tokenId;
    }

    /// @dev Overrides _mint to include attribute generation
    /// @param _to The token recipient
    /// @param _tokenId The ERC-721 token id
    function _mint(address _to, uint256 _tokenId) internal override {
        // Mint the token
        super._mint(_to, _tokenId);

        // Generate the token attributes
        getMetadataRenderer().generate(_tokenId);
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
    function burn(uint256 _tokenId) public onlyFromAuction {
        // Burn the token
        _burn(_tokenId);
    }

    ///                                                          ///
    ///                              URI                         ///
    ///                                                          ///

    /// @notice The URI for a given token
    /// @param _tokenId The ERC-721 token id
    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        return getMetadataRenderer().tokenURI(_tokenId);
    }

    /// @notice The URI for the contract
    function contractURI() public view override returns (string memory) {
        return getMetadataRenderer().contractURI();
    }

    ///                                                          ///
    ///                        CONTRACT UPGRADE                  ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract and that the new implementation is valid
    /// @dev This function is called in `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The address of the new implementation
    function _authorizeUpgrade(address _newImpl) internal view override {
        // Ensure the caller is the shared owner of the token and metadata renderer
        if (msg.sender != owner) {
            revert ONLY_OWNER();
        }

        // Ensure the implementation is valid
        if (!manager.isValidUpgrade(_getImplementation(), _newImpl)) {
            revert INVALID_UPGRADE(_newImpl);
        }
    }
}
