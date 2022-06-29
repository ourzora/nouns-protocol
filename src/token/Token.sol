// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
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
contract Token is UUPSUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable, ERC721VotesUpgradeable, TokenStorageV1 {
    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IUpgradeManager public immutable upgradeManager;

    /// @notice The metadata renderer implementation
    address public immutable metadataImpl;

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    /// @param _upgradeManager The address of the contract upgrade manager
    constructor(address _upgradeManager, address _metadataImpl) payable initializer {
        upgradeManager = IUpgradeManager(_upgradeManager);
        metadataImpl = _metadataImpl;
    }

    ///                                                          ///
    ///                          INITIALIZER                     ///
    ///                                                          ///

    /// @notice Called by the deployer to initialize the token proxy
    /// @param _name The token name
    /// @param _symbol The token $SYMBOL
    /// @param _foundersDAO The address of the founders DAO
    /// @param _foundersMaxAllocation The maximum number of tokens the founders will vest (eg. 183 nouns to nounders)
    /// @param _foundersAllocationFrequency The allocation frequency (eg. every 10 nouns)
    /// @param _auction The address of the auction house that will mint tokens
    function initialize(
        string calldata _name,
        string calldata _symbol,
        address _foundersDAO,
        uint256 _foundersMaxAllocation,
        uint256 _foundersAllocationFrequency,
        address _auction
    ) public initializer {
        // Initialize the reentrancy guard
        __ReentrancyGuard_init();

        // Initialize contract ownership
        __Ownable_init();

        // Transfer ownership to the founders DAO
        transferOwnership(_foundersDAO);

        // Initialize the ERC-721 token
        __ERC721_init(_name, _symbol);

        // Store the founders metadata
        founders.DAO = _foundersDAO;
        founders.maxAllocation = uint32(_foundersMaxAllocation);
        founders.allocationFrequency = uint32(_foundersAllocationFrequency);

        // Store the address allowed to mint tokens
        auction = _auction;

        // Deploy and store the metadata renderer
        metadataRenderer = IMetadataRenderer(address(new ERC1967Proxy(metadataImpl, abi.encodeWithSignature("initialize(address)", _foundersDAO))));
    }

    ///                                                          ///
    ///                              MINT                        ///
    ///                                                          ///

    /// @notice Mints tokens to the auction house for bidding and the founders DAO for vesting
    function mint() public nonReentrant returns (uint256) {
        // Ensure the caller is the auction house
        require(msg.sender == auction, "ONLY_AUCTION");

        unchecked {
            // If the token belongs to the founders:
            if (founders.currentAllocation < founders.maxAllocation && totalSupply % founders.allocationFrequency == 0) {
                // Send the token to the founders
                _mint(founders.DAO, totalSupply++);

                // Update their vested allocation
                ++founders.currentAllocation;
            }

            // Mint the next token for bidding
            _mint(auction, totalSupply++);

            return totalSupply - 1;
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
    ///                               URI                        ///
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
        require(upgradeManager.isValidUpgrade(_getImplementation(), _newImpl), "INVALID_UPGRADE");
    }
}
