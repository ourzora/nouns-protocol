// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {ERC721VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/draft-ERC721VotesUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {TokenStorageV1} from "./storage/TokenStorageV1.sol";
import {IMetadataRenderer} from "./metadata/IMetadataRenderer.sol";
import {IUpgradeManager} from "../upgrade/IUpgradeManager.sol";
import {IToken} from "./IToken.sol";

/// @title Nounish ERC-721 Token
/// @author Rohan Kulkarni
/// @notice Modified version of NounsToken.sol (commit 2cbe6c7) that NounsDAO licensed under the GPL-3.0 license
contract Token is TokenStorageV1, ERC721VotesUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IUpgradeManager public immutable UpgradeManager;

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    /// @param _upgradeManager The address of the contract upgrade manager
    constructor(address _upgradeManager) payable initializer {
        UpgradeManager = IUpgradeManager(_upgradeManager);
    }

    ///                                                          ///
    ///                          INITIALIZER                     ///
    ///                                                          ///

    /// @notice Called by the deployer to initialize the token proxy
    /// @param _name The token name
    /// @param _symbol The token $SYMBOL
    /// @param _metadataRenderer The address of the metadata renderer
    /// @param _foundersDAO The address of the founders DAO
    /// @param _foundersMaxAllocation The maximum number of tokens the founders will vest (eg. 183 nouns to nounders)
    /// @param _foundersAllocationFrequency The allocation frequency (eg. every 10 nouns)
    /// @param _treasury The address of the treasury to own the contract
    /// @param _auction The address of the auction house that will mint tokens
    function initialize(
        string memory _name,
        string memory _symbol,
        address _metadataRenderer,
        address _foundersDAO,
        uint256 _foundersMaxAllocation,
        uint256 _foundersAllocationFrequency,
        address _treasury,
        address _auction
    ) public initializer {
        // Initialize the ERC-721 token
        __ERC721_init(_name, _symbol);

        // Initialize the reentrancy guard
        __ReentrancyGuard_init();

        // Initialize contract ownership
        __Ownable_init();

        // Transfer ownership to the DAO treasury
        transferOwnership(_treasury);

        // Set metadata renderer
        metadataRenderer = IMetadataRenderer(_metadataRenderer);

        // Store the founders metadata
        founders.DAO = _foundersDAO;
        founders.maxAllocation = uint32(_foundersMaxAllocation);
        founders.allocationFrequency = uint32(_foundersAllocationFrequency);

        // Store the address allowed to mint tokens
        auction = _auction;
    }

    ///                                                          ///
    ///                              MINT                        ///
    ///                                                          ///

    /// @notice Mints tokens to the auction house for bidding and the founders DAO for vesting
    function mint() public nonReentrant returns (uint256) {
        // Ensure the caller is the auction house
        require(msg.sender == auction, "ONLY_AUCTION");

        // TODO start with token id 0 or 1?
        unchecked {
            // If the token belongs to the founders:
            if (founders.currentAllocation < founders.maxAllocation && totalSupply % founders.allocationFrequency == 0) {
                // Send the token to the founders
                _mint(founders.DAO, ++totalSupply);

                // Update their vested allocation
                ++founders.currentAllocation;
            }

            // Mint the next token for bidding
            _mint(auction, ++totalSupply);

            return totalSupply;
        }
    }

    ///                                                          ///
    ///                             BURN                         ///
    ///                                                          ///

    /// @notice Burns a token that did not have any bids
    /// @param _tokenId The token id to burn
    function burn(uint256 _tokenId) public {
        // Ensure the caller is the auction house
        require(msg.sender == auction, "ONLY_AUCTION");

        // Burn the token
        _burn(_tokenId);
    }

    ///                                                          ///
    ///                              META                        ///
    ///                                                          ///

    ///
    ///
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return metadataRenderer.tokenURI(tokenId);
    }

    ///
    function contractURI() public view returns (string memory) {
        return metadataRenderer.contractURI();
    }

    ///
    function foundersDAO() public view returns (address) {
        return founders.DAO;
    }

    ///                                                          ///
    ///                         UPDATE AUCTION                   ///
    ///                                                          ///

    /// @notice Emitted when the auction is updated
    /// @param auction The address of the new auction
    event AuctionUpdated(address auction);

    /// @notice Updates the address of the auction
    /// @param _auction The address of the auction to set
    function setAuction(address _auction) external onlyOwner {
        // Update the auction address
        auction = _auction;

        emit AuctionUpdated(_auction);
    }

    ///                                                          ///
    ///                        UPDATE FOUNDERS                   ///
    ///                                                          ///

    /// @notice Emitted when the founders DAO is updated
    /// @param foundersDAO The updated address of the founders DAO
    event FoundersDAOUpdated(address foundersDAO);

    /// @notice Updates the address of the founders DAO
    /// @param _foundersDAO The address of the founders DAO to set
    function setFoundersDAO(address _foundersDAO) external {
        // Ensure the caller is the founders
        require(msg.sender == founders.DAO, "ONLY_FOUNDERS");

        // Update the founders DAO address
        founders.DAO = _foundersDAO;

        emit FoundersDAOUpdated(_foundersDAO);
    }

    ///                                                          ///
    ///                         PROXY UPGRADE                    ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract to a valid implementation
    /// @dev This function is called in UUPS `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The address of the new implementation
    function _authorizeUpgrade(address _newImpl) internal override onlyOwner {
        // Ensure the implementation is valid
        require(UpgradeManager.isValidUpgrade(_getImplementation(), _newImpl), "INVALID_UPGRADE");
    }
}
