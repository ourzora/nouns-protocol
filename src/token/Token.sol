// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

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
contract Token is UUPSUpgradeable, ReentrancyGuardUpgradeable, ERC721VotesUpgradeable, TokenStorageV1 {
    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IUpgradeManager public immutable upgradeManager;

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    /// @param _upgradeManager The address of the contract upgrade manager
    constructor(address _upgradeManager) payable initializer {
        upgradeManager = IUpgradeManager(_upgradeManager);
    }

    ///                                                          ///
    ///                          INITIALIZER                     ///
    ///                                                          ///

    /// @notice Initializes an ERC-1967 proxy instance of the token
    /// @param _init The encoded token and metadata init strings
    /// @param _foundersDAO The address of the founders DAO
    /// @param _foundersMaxTokens The maximum number of tokens the founders will vest (eg. 183 nouns to nounders)
    /// @param _foundersAllocationFrequency The allocation frequency (eg. every 10 nouns)
    /// @param _auction The address of the auction house that will mint tokens
    function initialize(
        bytes calldata _init,
        address _metadataRenderer,
        address _foundersDAO,
        uint256 _foundersMaxTokens,
        uint256 _foundersAllocationFrequency,
        address _auction
    ) public initializer {
        // Initialize the reentrancy guard
        __ReentrancyGuard_init();

        // Decode the strings required to initialize the token
        (string memory _name, string memory _symbol, , , ) = abi.decode(_init, (string, string, string, string, string));

        // Initialize the ERC-721 token
        __ERC721_init(_name, _symbol);

        // Store the founders metadata
        founders.DAO = _foundersDAO;
        founders.maxAllocation = uint32(_foundersMaxTokens);
        founders.allocationFrequency = uint32(_foundersAllocationFrequency);

        // Store the address of the auction house that will mint tokens
        auction = _auction;

        // Store the metadata renderer for the token
        metadataRenderer = IMetadataRenderer(_metadataRenderer);
    }

    ///                                                          ///
    ///                              MINT                        ///
    ///                                                          ///

    /// @notice Mints tokens to the auction house for bidding and the founders DAO for vesting
    function mint() public nonReentrant returns (uint256 tokenId) {
        // Ensure the caller is the auction house
        require(msg.sender == auction, "ONLY_AUCTION");

        // Cannot realistically overflow on human time scales
        unchecked {
            // Get the next token id to mint
            tokenId = totalSupply++;
        }

        // If the token is valid for vesting:
        if (_isFoundersVest(tokenId)) {
            // Mint the token to the founders
            _mint(founders.DAO, tokenId);

            unchecked {
                // Update the number of vested tokens
                ++founders.currentAllocation;

                // Get the next token id
                tokenId = totalSupply++;
            }
        }

        // Mint the next token to the auction house for bidding
        _mint(auction, tokenId);

        return tokenId;
    }

    /// @dev Checks if the given token id is valid to send to the founders
    /// @param _tokenId The ERC-721 token id
    function _isFoundersVest(uint256 _tokenId) private view returns (bool valid) {
        uint256 currentAllocation = founders.currentAllocation;
        uint256 maxAllocation = founders.maxAllocation;
        uint256 allocationFrequency = founders.allocationFrequency;

        assembly {
            // founders.currentAllocation < founders.maxAllocation && _tokenId % founders.allocationFrequency == 0
            valid := and(lt(currentAllocation, maxAllocation), iszero(mod(_tokenId, allocationFrequency)))
        }
    }

    /// @dev Overrides _mint to include attribute generation
    /// @param _to The address to send the token
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

    /// @notice The URI for a given token
    /// @param _tokenId The ERC-721 token id
    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        return metadataRenderer.tokenURI(_tokenId);
    }

    /// @notice The URI for the contract
    function contractURI() public view returns (string memory) {
        return metadataRenderer.contractURI();
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
        // Ensure the caller is the founders DAO
        require(msg.sender == founders.DAO, "ONLY_FOUNDERS");

        // Update the founders DAO address
        founders.DAO = _foundersDAO;

        emit FoundersDAOUpdated(_foundersDAO);
    }

    event FoundersVestingAllocation(uint256 numTokens);

    function setFoundersVestingAllocation(uint256 _numTokens) external onlyOwner {
        require(_numTokens < type(uint32).max, "");

        founders.maxAllocation = uint32(_numTokens);

        emit FoundersVestingAllocation(_numTokens);
    }

    event FoundersVestingSchedule(uint256 numTokens);

    function setFoundersVestingSchedule(uint256 _tokenInterval) external onlyOwner {
        require(_tokenInterval < type(uint32).max, "");

        founders.allocationFrequency = uint32(_tokenInterval);

        emit FoundersVestingSchedule(_tokenInterval);
    }

    /// @notice Called by the auction house upon bid settlement to auto-delegate the winner their vote
    /// @param _user The address of the winning bidder
    function autoDelegate(address _user) external {
        // Ensure the caller is the auction house
        require(msg.sender == auction, "ONLY_AUCTION");

        // Delegate the winning bidder's voting unit to themselves
        _delegate(_user, _user);
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    modifier onlyOwner() {
        require(msg.sender == metadataRenderer.owner(), "ONLY_OWNER");
        _;
    }

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
