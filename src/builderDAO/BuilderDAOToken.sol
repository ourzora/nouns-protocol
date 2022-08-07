// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC721VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/draft-ERC721VotesUpgradeable.sol";

import {TokenStorageV1} from "../token/storage/TokenStorageV1.sol";
import {IMetadataRenderer} from "../token/metadata/IMetadataRenderer.sol";
import {IUpgradeManager} from "../upgrade/IUpgradeManager.sol";
import {IToken} from "../token/IToken.sol";

contract BuilderDAOToken is UUPSUpgradeable, ReentrancyGuardUpgradeable, ERC721VotesUpgradeable, TokenStorageV1 {
    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IUpgradeManager private immutable upgradeManager;

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

    /// @notice Initializes an ERC-1967 proxy instance of this token implementation
    /// @param _init The encoded token and metadata initialization strings
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

        // Decode the token initialization strings
        (string memory _name, string memory _symbol, , , ) = abi.decode(_init, (string, string, string, string, string));

        // Initialize the ERC-721 token
        __ERC721_init(_name, _symbol);

        // Store the founders' vesting details
        founders.DAO = _foundersDAO;
        founders.maxAllocation = uint32(_foundersMaxTokens);
        founders.allocationFrequency = uint32(_foundersAllocationFrequency);

        // Store the associated auction house
        auction = _auction;

        // Store the associated metadata renderer
        metadataRenderer = IMetadataRenderer(_metadataRenderer);
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
            // Get the next available token id
            tokenId = totalSupply++;

            if (_isForFounders(tokenId)) {
                // Update the number of tokens vested to the founders
                ++founders.currentAllocation;

                // Mint the token to the founders
                _mint(founders.DAO, tokenId);

                // Get the next available token id
                tokenId = totalSupply++;
            }
        }

        // Mint the next token to the auction house for bidding
        _mint(auction, tokenId);

        return tokenId;
    }

    /// @dev If a token meets the founders' vesting schedule
    /// @param _tokenId The ERC-721 token id
    function _isForFounders(uint256 _tokenId) private view returns (bool vest) {
        uint256 numVested = founders.currentAllocation;
        uint256 vestingTotal = founders.maxAllocation;
        uint256 vestingSchedule = founders.allocationFrequency;

        assembly {
            vest := and(lt(numVested, vestingTotal), iszero(mod(_tokenId, vestingSchedule)))
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
    ///                           DELEGATION                     ///
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
