// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {ERC721VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/draft-ERC721VotesUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IMetadataRenderer} from "./metadata/IMetadataRenderer.sol";

import {IUpgradeManager} from "../UpgradeManager.sol";

// import {IToken} from "./IToken.sol";

/**
    TODO
    - Metadata Rendering
    - Ownership / Upgrade Manager
    - Vesting
        - handle dynamic number of recipients
        - handle overlapping vests and priority of recipients
    
 */
contract Token is ERC721VotesUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    /// @notice
    IUpgradeManager private immutable UpgradeManager;

    /// @notice
    uint256 private immutable DAOFee;

    /// @notice
    address private immutable DAOFeeRecipient;

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    constructor(
        address _upgradeManager,
        uint256 _daoFee,
        address _daoFeeRecipient
    ) payable initializer {
        UpgradeManager = IUpgradeManager(_upgradeManager);

        DAOFee = _daoFee;

        DAOFeeRecipient = _daoFeeRecipient;
    }

    ///                                                          ///
    ///                          INITIALIZER                     ///
    ///                                                          ///

    function initialize(
        string memory _name,
        string memory _symbol,
        IMetadataRenderer _metadataRenderer,
        address _foundersDAO,
        uint256 _foundersMaxAllocation,
        uint256 _foundersAllocationFrequency,
        address _minter
    ) public initializer {
        // Initialize the ERC-721 token
        __ERC721_init(_name, _symbol);

        // Initialize the reentracy guard
        __ReentrancyGuard_init();

        // Initialize ownership of the contract
        __Ownable_init();

        // Transfer ownership to the founders
        transferOwnership(_foundersDAO);

        // Initialize the metadata renderer
        metadataRenderer = _metadataRenderer;

        // Store the founders metadata
        founders.DAO = _foundersDAO;
        founders.maxAllocation = uint32(_foundersMaxAllocation);
        founders.allocationFrequency = uint32(_foundersAllocationFrequency);

        // Store the address allowed to mint tokens
        minter = _minter;
    }

    ///                                                          ///
    ///                        FOUNDERS STORAGE                  ///
    ///                                                          ///

    /// @notice The metadata of the founders
    /// @param DAO The founders DAO address
    /// @param maxAllocation The maximum number of tokens that will be vested
    /// @param currentAllocation The current number of tokens vested
    /// @param allocationFrequency The interval between tokens to vest to the founders
    struct Founders {
        address DAO;
        uint32 maxAllocation;
        uint32 currentAllocation;
        uint32 allocationFrequency;
    }

    /// @notice
    Founders public founders;

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

        // Store the updated DAO address
        founders.DAO = _foundersDAO;

        emit FoundersDAOUpdated(_foundersDAO);
    }

    ///                                                          ///
    ///                         UPDATE MINTER                    ///
    ///                                                          ///

    address public minter;

    event MinterUpdated(address minter);

    function setMinter(address _minter) external onlyOwner {
        minter = _minter;

        emit MinterUpdated(_minter);
    }

    ///                                                          ///
    ///                              MINT                        ///
    ///                                                          ///

    /// @notice The token id tracker
    uint256 public tokenCount;

    // TODO handle vesting overlaps and other recipients
    function mint() public returns (uint256) {
        // Ensure the caller is the minter
        require(msg.sender == minter, "ONLY_MINTER");

        // Used to store the current token id
        uint256 currentTokenId;

        // Get the current token id and increment the total count
        unchecked {
            currentTokenId = ++tokenCount;
        }

        // If the founders are still vesting and this is a valid token to vest:
        if (founders.currentAllocation < founders.maxAllocation && currentTokenId % founders.allocationFrequency == 0) {
            // Send the founders DAO the token
            _mint(founders.DAO, currentTokenId);

            // Increment the founders DAO allocation
            unchecked {
                ++founders.currentAllocation;
            }

            // Otherwise send the token to the auction house for bidding
        } else {
            _mint(minter, currentTokenId);
        }

        return currentTokenId;
    }

    function _mint(address receiver, uint256 tokenUri) internal override {
        _mint(receiver, tokenUri);
        metadataRenderer.minted(tokenUri);
    }

    ///                                                          ///
    ///                             BURN                         ///
    ///                                                          ///

    function burn(uint256 tokenId) public {
        // wouldn't this need to be the owner?
        require(msg.sender == minter, "ONLY_MINTER");

        _burn(tokenId);
    }

    ///                                                          ///
    ///                       METADATA RENDERER                  ///
    ///                                                          ///

    ///                                                          ///
    ///                          TOKEN URI                       ///
    ///                                                          ///

    ///                                                          ///
    ///                         CONTRACT URI                     ///
    ///                                                          ///

    ///                                                          ///
    ///                         PROXY UPGRADE                    ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract
    /// @dev This function is called in UUPS `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The address of the new implementation
    function _authorizeUpgrade(address _newImpl) internal view override {
        // Ensure the caller is the upgrade manager
        require(msg.sender == address(UpgradeManager), "ONLY_UPGRADE_MANAGER");

        // Ensure the implementation is valid
        // require(UpgradeManager.isValidUpgrade(_newImpl, _getImplementation()), "INVALID_IMPLEMENTATION");
    }

    function contractURI() public view returns (string memory) {
        metadataRenderer.contractURI();
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        metadataRenderer.tokenURI(tokenId);
    }
}
