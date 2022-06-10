// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {ERC721VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/draft-ERC721VotesUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IUpgradeManager} from "../upgrades/IUpgradeManager.sol";
import {TokenStorageV1} from "./storage/TokenStorageV1.sol";

/// @title Nounish ERC-721 Token
/// @author Rohan Kulkarni
/// @notice Modified version of NounsToken.sol (commit 2cbe6c7) that NounsDAO licensed under the GPL-3.0 license
contract Token is TokenStorageV1, ERC721VotesUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IUpgradeManager private immutable UpgradeManager;

    /// @notice The Nouns Builder DAO
    address private immutable DAO;

    /// @notice The Nouns Builder DAO Fee
    uint256 private immutable DAOFee;

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    /// @param _upgradeManager The address of the contract upgrade manager
    /// @param _dao The address of the Nouns Builder DAO
    /// @param _daoFee The allocation frequency of tokens
    constructor(
        address _upgradeManager,
        address _dao,
        uint256 _daoFee
    ) payable initializer {
        UpgradeManager = IUpgradeManager(_upgradeManager);
        DAO = _dao;
        DAOFee = _daoFee;
    }

    ///                                                          ///
    ///                          INITIALIZER                     ///
    ///                                                          ///

    /// @notice Called by the proxy to initialize the contract
    /// @param _name The token name
    /// @param _symbol The token $SYMBOL
    /// @param _metadataRenderer TBD
    /// @param _metadataRendererInitData TBD
    /// @param _foundersDAO The address of the founders DAO
    /// @param _foundersMaxAllocation The maximum number of tokens the founders will vest (eg. 183 nouns to nounders)
    /// @param _foundersAllocationFrequency The allocation frequency (eg. every 10 nouns)
    /// @param _treasury The address of the treasury to own the contract
    /// @param _minter The address of the auction house to mint tokens
    function initialize(
        string memory _name,
        string memory _symbol,
        address _metadataRenderer,
        bytes memory _metadataRendererInitData,
        address _foundersDAO,
        uint256 _foundersMaxAllocation,
        uint256 _foundersAllocationFrequency,
        address _treasury,
        address _minter
    ) public initializer {
        // Initialize the proxy
        __UUPSUpgradeable_init();

        // Initialize the ERC-721 token
        __ERC721_init(_name, _symbol);

        // Initialize the reentrancy guard
        __ReentrancyGuard_init();

        // Initialize contract ownership
        __Ownable_init();

        // Transfer ownership to the DAO treasury
        transferOwnership(_treasury);

        // Store the founders metadata
        founders.DAO = _foundersDAO;
        founders.maxAllocation = uint32(_foundersMaxAllocation);
        founders.allocationFrequency = uint32(_foundersAllocationFrequency);

        // Store the address allowed to mint tokens
        minter = _minter;
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
    ///                         UPDATE MINTER                    ///
    ///                                                          ///

    /// @notice Emitted when the minter is updated
    /// @param minter The address of the new minter
    event MinterUpdated(address minter);

    /// @notice Updates the address of the minter
    /// @param _minter The address of the minter to set
    function setMinter(address _minter) external onlyOwner {
        // Update the minter address
        minter = _minter;

        emit MinterUpdated(_minter);
    }

    ///                                                          ///
    ///                              MINT                        ///
    ///                                                          ///

    /// @notice Mints a token to the minter and handles vesting allocations
    function mint() public nonReentrant returns (uint256) {
        // Ensure the caller is the minter
        require(msg.sender == minter, "ONLY_MINTER");

        unchecked {
            // If the token is valid to vest for both the founders and Nouns Builder DAO:
            if (_isFoundersVest(tokenCount) && _isDAOVest(tokenCount)) {
                // Send the first token to the founders
                _mint(founders.DAO, ++tokenCount);

                // Update the founders allocation
                ++founders.currentAllocation;

                // Send the next token to the DAO
                _mint(DAO, ++tokenCount);

                // Else if the token is just for the founders:
            } else if (_isFoundersVest(tokenCount)) {
                // Send the token to the founders
                _mint(founders.DAO, ++tokenCount);

                // Update the founders allocation
                ++founders.currentAllocation;

                // Else if the token is just for the DAO:
            } else if (_isDAOVest(tokenCount)) {
                // Send the token to the DAO
                _mint(DAO, ++tokenCount);
            }

            // Send the next token to the minter
            _mint(minter, ++tokenCount);

            return tokenCount;
        }
    }

    /// @notice If the founders are still vesting AND the given token fits their vesting criteria
    /// @param _tokenId The ERC-721 token id
    function _isFoundersVest(uint256 _tokenId) private view returns (bool) {
        return founders.currentAllocation < founders.maxAllocation && _tokenId % founders.allocationFrequency == 0;
    }

    /// @notice If the given token fits the DAO vesting criteria
    /// @param _tokenId The ERC-721 token id
    function _isDAOVest(uint256 _tokenId) private view returns (bool) {
        return _tokenId % DAOFee == 0;
    }

    ///                                                          ///
    ///                             BURN                         ///
    ///                                                          ///

    /// @notice Burns a token that did not have any bids
    /// @param _tokenId The token id to burn
    function burn(uint256 _tokenId) public {
        // Ensure the caller is the minter
        require(msg.sender == minter, "ONLY_MINTER");

        // Burn the token
        _burn(_tokenId);
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
