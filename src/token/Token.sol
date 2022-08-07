// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC721VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/draft-ERC721VotesUpgradeable.sol";

import {TokenStorageV1} from "./storage/TokenStorageV1.sol";
import {IMetadataRenderer} from "./metadata/IMetadataRenderer.sol";
import {IUpgradeManager} from "../upgrade/IUpgradeManager.sol";
import {IToken} from "./IToken.sol";

/// @title Nounish ERC-721 Token
/// @author Rohan Kulkarni
/// @notice Modified version of NounsToken.sol (commit 2cbe6c7) that NounsDAO licensed under the GPL-3.0 license
contract Token is UUPSUpgradeable, ReentrancyGuardUpgradeable, ERC721VotesUpgradeable, TokenStorageV1 {
    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IUpgradeManager private immutable upgradeManager;

    /// @notice The Nouns Builder DAO address
    address public immutable nounsBuilderDAO;

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    /// @param _upgradeManager The address of the contract upgrade manager
    /// @param _nounsBuilderDAO The address of the Nouns Builder DAO
    constructor(address _upgradeManager, address _nounsBuilderDAO) payable initializer {
        upgradeManager = IUpgradeManager(_upgradeManager);
        nounsBuilderDAO = _nounsBuilderDAO;
    }

    ///                                                          ///
    ///                          INITIALIZER                     ///
    ///                                                          ///

    function initialize(
        address[] calldata _founderWallets,
        uint8[] calldata _founderPercentages,
        bytes calldata _tokenStrings,
        address _metadataRenderer,
        address _auction
    ) public initializer {
        // Initialize the reentrancy guard
        __ReentrancyGuard_init();

        // Decode the token initialization strings
        (string memory _name, string memory _symbol, , , ) = abi.decode(_tokenStrings, (string, string, string, string, string));

        // Initialize the ERC-721 token
        __ERC721_init(_name, _symbol);

        // Store the associated auction house
        auction = _auction;

        // Store the associated metadata renderer
        metadataRenderer = IMetadataRenderer(_metadataRenderer);

        // Store the founders' vesting details
        _storeFounders(_founderWallets, _founderPercentages);
    }

    function _storeFounders(address[] memory _wallets, uint8[] memory _percentages) internal {
        require(_wallets.length == _percentages.length, "");
        require(_wallets[0] != address(0), "");

        uint256 totalPercentage;

        // TODO calculate MCD

        for (uint256 i; i < _wallets.length; ) {
            require(totalPercentage < 100, "");

            founders.push();

            founders[i].wallet = _wallets[i];
            founders[i].percent = _percentages[i];

            unchecked {
                totalPercentage += _percentages[i];

                ++i;
            }
        }
    }

    ///                                                          ///
    ///                              MINT                        ///
    ///                                                          ///

    /// @notice Mints tokens to the auction house for bidding and handles vesting to the founders & Nouns Builder DAO
    function mint() public nonReentrant returns (uint256 tokenId) {
        // Ensure the caller is the auction house
        require(msg.sender == auction, "ONLY_AUCTION");

        // Cannot realistically overflow uint32 or uint256 counters
        unchecked {
            do {
                // Get the next available token id
                tokenId = totalSupply++;

                // If the token is reserved for the builderDAO:
                if (_isForNounsBuilderDAO(tokenId)) {
                    _mint(nounsBuilderDAO, tokenId);

                    tokenId = totalSupply++;
                }

                // If this token is reserved for a founder, send it to them
                if (founders[tokenId % founders.length].wallet != address(0)) {
                    _mint(founders[tokenId % founders.length].wallet, tokenId);

                    tokenId = totalSupply++;
                }
            } while (founders[tokenId % founders.length].wallet != address(0));

            // Mint the next token to the auction house for bidding
            _mint(auction, tokenId);
        }

        return tokenId;
    }

    /// @dev If a token meets the Nouns Builder DAO vesting schedule
    /// @param _tokenId The ERC-721 token id
    function _isForNounsBuilderDAO(uint256 _tokenId) private pure returns (bool vest) {
        assembly {
            vest := iszero(mod(add(_tokenId, 1), 100))
        }
    }

    /// @dev Overrides _mint to include attribute generation
    /// @param _to The token recipient
    /// @param _tokenId The ERC-721 token id
    function _mint(address _to, uint256 _tokenId) internal override {
        // Mint the token
        super._mint(_to, _tokenId);

        // Generate the token attributes
        metadataRenderer.generate(_tokenId);
    }

    ///                                                          ///
    ///                             BURN                         ///
    ///                                                          ///

    /// @notice Burns a token that did not see any bids
    /// @param _tokenId The ERC-721 token id
    function burn(uint256 _tokenId) public {
        // Ensure the caller is the auction house
        require(msg.sender == auction, "ONLY_AUCTION");

        // Burn the token
        _burn(_tokenId);
    }

    ///                                                          ///
    ///                              URI                         ///
    ///                                                          ///

    /// @notice The URI for the given token
    /// @param _tokenId The ERC-721 token id
    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        return metadataRenderer.tokenURI(_tokenId);
    }

    /// @notice The URI for the contract
    function contractURI() public view returns (string memory) {
        return metadataRenderer.contractURI();
    }

    ///                                                          ///
    ///                          FOUNDERS DAO                    ///
    ///                                                          ///

    /// @notice Called by the auction house upon bid settlement to auto-delegate the winner their vote
    /// @param _user The address of the winning bidder
    function autoDelegate(address _user) external {
        // Ensure the caller is the auction house
        require(msg.sender == auction, "ONLY_AUCTION");

        // Delegate the winning bidder's voting unit to themselves
        _delegate(_user, _user);
    }

    ///                                                          ///
    ///                             OWNER                        ///
    ///                                                          ///

    /// @dev Ensures the caller is the contract owner
    modifier onlyOwner() {
        require(msg.sender == metadataRenderer.owner(), "ONLY_OWNER");
        _;
    }

    /// @notice Returns the address of the contract owner
    function owner() external view returns (address) {
        return metadataRenderer.owner();
    }

    ///                                                          ///
    ///                         PROXY UPGRADE                    ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract to a valid implementation
    /// @dev This function is called in UUPS `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The address of the new implementation
    function _authorizeUpgrade(address _newImpl) internal override onlyOwner {
        // Ensure the implementation is valid
        require(upgradeManager.isValidUpgrade(_getImplementation(), _newImpl), "INVALID_UPGRADE");
    }
}
