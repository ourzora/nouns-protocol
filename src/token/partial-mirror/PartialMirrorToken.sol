// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { UUPS } from "../../lib/proxy/UUPS.sol";
import { ReentrancyGuard } from "../../lib/utils/ReentrancyGuard.sol";
import { ERC721Votes } from "../../lib/token/ERC721Votes.sol";
import { ERC721 } from "../../lib/token/ERC721.sol";
import { IERC721 } from "../../lib/interfaces/IERC721.sol";
import { Ownable } from "../../lib/utils/Ownable.sol";
import { PartialMirrorTokenStorageV1 } from "./storage/PartialMirrorTokenStorageV1.sol";
import { IToken } from "../default/IToken.sol";
import { IBaseToken } from "../interfaces/IBaseToken.sol";
import { TokenStorageV1 } from "../default/storage/TokenStorageV1.sol";
import { TokenStorageV2 } from "../default/storage/TokenStorageV2.sol";
import { TokenStorageV3 } from "../default/storage/TokenStorageV3.sol";
import { IBaseMetadata } from "../../metadata/interfaces/IBaseMetadata.sol";
import { IManager } from "../../manager/IManager.sol";
import { IAuction } from "../../auction/IAuction.sol";
import { IPartialMirrorToken } from "./IPartialMirrorToken.sol";
import { VersionedContract } from "../../VersionedContract.sol";

import { IMirrorToken } from "../interfaces/IMirrorToken.sol";

/// @title Token
/// @author Neokry
/// @custom:repo github.com/ourzora/nouns-protocol
/// @notice A DAO's ERC-721 governance token modified to support partial soulbinding
contract PartialMirrorToken is
    IPartialMirrorToken,
    VersionedContract,
    UUPS,
    Ownable,
    ReentrancyGuard,
    ERC721Votes,
    TokenStorageV1,
    TokenStorageV2,
    TokenStorageV3,
    PartialMirrorTokenStorageV1
{
    ///                                                          ///
    ///                         IMMUTABLES                       ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IManager private immutable manager;

    ///                                                          ///
    ///                          MODIFIERS                       ///
    ///                                                          ///

    /// @notice Reverts if caller is not an authorized minter
    modifier onlyMinter() {
        if (!minter[msg.sender]) {
            revert ONLY_AUCTION_OR_MINTER();
        }

        _;
    }

    /// @notice Reverts if caller is not an authorized minter
    modifier onlyAuctionOrMinter() {
        if (msg.sender != settings.auction && !minter[msg.sender]) {
            revert ONLY_AUCTION_OR_MINTER();
        }

        _;
    }

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
    /// @param _reservedUntilTokenId The tokenId that a DAO's auctions will start at
    /// @param _metadataRenderer The token's metadata renderer
    /// @param _auction The token's auction house
    /// @param _initialOwner The initial owner of the token
    function initialize(
        IManager.FounderParams[] calldata _founders,
        bytes calldata _initStrings,
        uint256 _reservedUntilTokenId,
        address _tokenToMirror,
        address _metadataRenderer,
        address _auction,
        address _initialOwner
    ) external initializer {
        // Ensure the caller is the contract manager
        if (msg.sender != address(manager)) {
            revert ONLY_MANAGER();
        }

        // Initialize the reentrancy guard
        __ReentrancyGuard_init();

        // Setup ownable
        __Ownable_init(_initialOwner);

        // Store the founders and compute their allocations
        _addFounders(_founders, _reservedUntilTokenId);

        // Decode the token name and symbol
        (string memory _name, string memory _symbol, , , , ) = abi.decode(_initStrings, (string, string, string, string, string, string));

        // Initialize the ERC-721 token
        __ERC721_init(_name, _symbol);

        // Store the metadata renderer and auction house
        settings.metadataRenderer = IBaseMetadata(_metadataRenderer);
        settings.auction = _auction;
        reservedUntilTokenId = _reservedUntilTokenId;
        tokenToMirror = _tokenToMirror;
    }

    /// @notice Called by the auction upon the first unpause / token mint to transfer ownership from founder to treasury
    /// @dev Only callable by the auction contract
    function onFirstAuctionStarted() external {
        if (msg.sender != settings.auction) {
            revert ONLY_AUCTION();
        }

        // Force transfer ownership to the treasury
        _transferOwnership(IAuction(settings.auction).treasury());
    }

    /// @notice Called upon initialization to add founders and compute their vesting allocations
    /// @dev We do this by reserving an mapping of [0-100] token indices, such that if a new token mint ID % 100 is reserved, it's sent to the appropriate founder.
    /// @param _founders The list of DAO founders
    function _addFounders(IManager.FounderParams[] calldata _founders, uint256 reservedUntilTokenId) internal {
        // Used to store the total percent ownership among the founders
        uint256 totalOwnership;

        uint8 numFoundersAdded = 0;

        unchecked {
            // For each founder:
            for (uint256 i; i < _founders.length; ++i) {
                // Cache the percent ownership
                uint256 founderPct = _founders[i].ownershipPct;

                // Continue if no ownership is specified
                if (founderPct == 0) {
                    continue;
                }

                // Update the total ownership and ensure it's valid
                totalOwnership += founderPct;

                // Check that founders own less than 100% of tokens
                if (totalOwnership > 99) {
                    revert INVALID_FOUNDER_OWNERSHIP();
                }

                // Compute the founder's id
                uint256 founderId = numFoundersAdded++;

                // Get the pointer to store the founder
                Founder storage newFounder = founder[founderId];

                // Store the founder's vesting details
                newFounder.wallet = _founders[i].wallet;
                newFounder.vestExpiry = uint32(_founders[i].vestExpiry);
                // Total ownership cannot be above 100 so this fits safely in uint8
                newFounder.ownershipPct = uint8(founderPct);

                // Compute the vesting schedule
                uint256 schedule = 100 / founderPct;

                // Used to store the base token id the founder will recieve
                uint256 baseTokenId = reservedUntilTokenId;

                // For each token to vest:
                for (uint256 j; j < founderPct; ++j) {
                    // Get the available token id
                    baseTokenId = _getNextTokenId(baseTokenId);

                    // Store the founder as the recipient
                    tokenRecipient[baseTokenId] = newFounder;

                    emit MintScheduled(baseTokenId, founderId, newFounder);

                    // Update the base token id
                    baseTokenId = (baseTokenId + schedule) % 100;
                }
            }

            // Store the founders' details
            settings.totalOwnership = uint8(totalOwnership);
            settings.numFounders = numFoundersAdded;
        }
    }

    /// @dev Finds the next available base token id for a founder
    /// @param _tokenId The ERC-721 token id
    function _getNextTokenId(uint256 _tokenId) internal view returns (uint256) {
        unchecked {
            while (tokenRecipient[_tokenId].wallet != address(0)) {
                _tokenId = (++_tokenId) % 100;
            }

            return _tokenId;
        }
    }

    ///                                                          ///
    ///                             MINT                         ///
    ///                                                          ///

    /// @notice Mints tokens to the caller and handles founder vesting
    function mint() external nonReentrant onlyAuctionOrMinter returns (uint256 tokenId) {
        tokenId = _mintWithVesting(msg.sender);
    }

    /// @notice Mints tokens to the recipient and handles founder vesting
    function mintTo(address recipient) external nonReentrant onlyAuctionOrMinter returns (uint256 tokenId) {
        tokenId = _mintWithVesting(recipient);
    }

    /// @notice Mints tokens from the reserve to the recipient
    function mintFromReserveTo(address recipient, uint256 tokenId) external nonReentrant onlyMinter {
        // Token must be reserved
        if (!_isReserved(tokenId)) revert TOKEN_NOT_RESERVED();

        // Mint the token without vesting (reserved tokens do not count towards founders vesting)
        _mint(recipient, tokenId);
    }

    /// @notice Mints the specified amount of tokens to the recipient and handles founder vesting
    function mintBatchTo(uint256 amount, address recipient) external nonReentrant onlyAuctionOrMinter returns (uint256[] memory tokenIds) {
        tokenIds = new uint256[](amount);
        for (uint256 i = 0; i < amount; ) {
            tokenIds[i] = _mintWithVesting(recipient);
            unchecked {
                ++i;
            }
        }
    }

    function _mintWithVesting(address recipient) internal returns (uint256 tokenId) {
        // Cannot realistically overflow
        unchecked {
            do {
                // Get the next token to mint
                tokenId = reservedUntilTokenId + settings.mintCount++;

                // Lookup whether the token is for a founder, and mint accordingly if so
            } while (_isForFounder(tokenId));
        }

        // Mint the next available token to the recipient for bidding
        _mint(recipient, tokenId);
    }

    /// @dev Overrides _mint to include attribute generation
    /// @param _to The token recipient
    /// @param _tokenId The ERC-721 token id
    function _mint(address _to, uint256 _tokenId) internal override {
        // Mint the token
        super._mint(_to, _tokenId);

        // Increment the total supply
        unchecked {
            ++settings.totalSupply;
        }

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

    function _isReserved(uint256 tokenId) internal view returns (bool) {
        return tokenId < reservedUntilTokenId;
    }

    ///                                                          ///
    ///                             Mirror                       ///
    ///                                                          ///

    /// @notice Gets the token address being mirrored
    /// @return The token address being mirrored
    function getTokenToMirror() external view override returns (address) {
        return tokenToMirror;
    }

    /// @notice Mirrors the ownership of a given tokenId from the mirrored token
    /// @param _tokenId The ERC-721 token to mirror
    function mirror(uint256 _tokenId) public {
        if (!_mirror(_tokenId)) {
            revert TOKEN_NOT_RESERVED();
        }
    }

    /// @notice Mirrors or transfers the given tokenId
    /// @param _from The sender address
    /// @param _to The recipient address
    /// @param _tokenId The ERC-721 token id
    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) public virtual override(ERC721, IERC721) {
        if (!_mirror(_tokenId)) {
            super.transferFrom(_from, _to, _tokenId);
        }
    }

    /// @notice Mirrors or safe transfers the given tokenId
    /// @param _from The sender address
    /// @param _to The recipient address
    /// @param _tokenId The ERC-721 token id
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) public virtual override(ERC721, IERC721) {
        if (!_mirror(_tokenId)) {
            super.safeTransferFrom(_from, _to, _tokenId);
        }
    }

    /// @notice Mirrors or safe transfers the given tokenId
    /// @param _from The sender address
    /// @param _to The recipient address
    /// @param _tokenId The ERC-721 token id
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata _data
    ) public virtual override(ERC721, IERC721) {
        if (!_mirror(_tokenId)) {
            super.safeTransferFrom(_from, _to, _tokenId, _data);
        }
    }

    function _mirror(uint256 _tokenId) internal returns (bool) {
        // Return if the token is not reserved and let the calling function handle this case
        if (!_isReserved(_tokenId)) {
            return false;
        }

        // Get owner of the current token
        address from = owners[_tokenId];

        // Get owner of the mirrored token
        address to = _ownerOfMirrored(_tokenId);

        // Owners already match so no need to mirror
        if (from == to) revert ALREADY_MIRRORED();

        if (from == address(0)) {
            // Not allowed to mirror tokens that have not been minted yet
            revert NOT_MINTED();
        } else if (to == address(0)) {
            // If the mirrored token has been burned then burn the token
            _burn(_tokenId);
        } else {
            // Transfer the token to the mirrored owner
            super._transfer(from, to, _tokenId);
        }

        // Mirroring has succeeded
        return true;
    }

    function _ownerOfMirrored(uint256 _tokenId) internal view returns (address) {
        // Check mirrored token owner or return address(0) if it doesn't exist
        try IERC721(tokenToMirror).ownerOf(_tokenId) returns (address mirrorOwner) {
            return mirrorOwner;
        } catch {
            return address(0);
        }
    }

    ///                                                          ///
    ///                             Approval                     ///
    ///                                                          ///

    function approve(address _to, uint256 _tokenId) public override(IERC721, ERC721) {
        // Disable approvals on tokens that can be mirrored
        if (_isReserved(_tokenId)) {
            revert NO_APPROVALS();
        } else {
            super.approve(_to, _tokenId);
        }
    }

    function getApproved(uint256 _tokenId) public view override(ERC721, IERC721) returns (address) {
        // Disable getting approvals on tokens that can be mirrored
        if (_isReserved(_tokenId)) {
            return address(0);
        } else {
            return super.getApproved(_tokenId);
        }
    }

    function setApprovalForAll(address, bool) public pure override(ERC721, IERC721) {
        // Disable approvals for all since mirrored tokens cannot be approved
        revert NO_APPROVALS();
    }

    function isApprovedForAll(address, address) public pure override(ERC721, IERC721) returns (bool) {
        return false;
    }

    ///                                                          ///
    ///                             BURN                         ///
    ///                                                          ///

    /// @notice Burns a token owned by the caller
    /// @param _tokenId The ERC-721 token id
    function burn(uint256 _tokenId) external onlyAuctionOrMinter {
        // Ensure the caller owns the token
        if (ownerOf(_tokenId) != msg.sender) {
            revert ONLY_TOKEN_OWNER();
        }

        _burn(_tokenId);
    }

    function _burn(uint256 _tokenId) internal override {
        // Call the parent burn function
        super._burn(_tokenId);

        // Reduce the total supply
        unchecked {
            --settings.totalSupply;
        }
    }

    ///                                                          ///
    ///                           METADATA                       ///
    ///                                                          ///

    /// @notice The URI for a token
    /// @param _tokenId The ERC-721 token id
    function tokenURI(uint256 _tokenId) public view override(ERC721, IBaseToken) returns (string memory) {
        return settings.metadataRenderer.tokenURI(_tokenId);
    }

    /// @notice The URI for the contract
    function contractURI() public view override(ERC721, IBaseToken) returns (string memory) {
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
            for (uint256 i; i < numFounders; ++i) {
                founders[i] = founder[i];
            }
        }

        return founders;
    }

    /// @notice The founder scheduled to receive the given token id
    /// NOTE: If a founder is returned, there's no guarantee they'll receive the token as vesting expiration is not considered
    /// @param _tokenId The ERC-721 token id
    function getScheduledRecipient(uint256 _tokenId) external view returns (Founder memory) {
        return tokenRecipient[_tokenId % 100];
    }

    /// @notice Update the list of allocation owners
    /// @param newFounders the full list of founders
    function updateFounders(IManager.FounderParams[] calldata newFounders) external onlyOwner {
        // Cache the number of founders
        uint256 numFounders = settings.numFounders;

        // Get a temporary array to hold all founders
        Founder[] memory cachedFounders = new Founder[](numFounders);

        // Cannot realistically overflow
        unchecked {
            // Add each founder to the array
            for (uint256 i; i < numFounders; ++i) {
                cachedFounders[i] = founder[i];
            }
        }

        // Keep a mapping of all the reserved token IDs we're set to clear.
        bool[] memory clearedTokenIds = new bool[](100);

        unchecked {
            // for each existing founder:
            for (uint256 i; i < cachedFounders.length; ++i) {
                // copy the founder into memory
                Founder memory cachedFounder = cachedFounders[i];

                // Delete the founder from the stored mapping
                delete founder[i];

                // Some DAOs were initialized with 0 percentage ownership.
                // This skips them to avoid a division by zero error.
                if (cachedFounder.ownershipPct == 0) {
                    continue;
                }

                // using the ownership percentage, get reserved token percentages
                uint256 schedule = 100 / cachedFounder.ownershipPct;

                // Used to reverse engineer the indices the founder has reserved tokens in.
                uint256 baseTokenId;

                for (uint256 j; j < cachedFounder.ownershipPct; ++j) {
                    // Get the next index that hasn't already been cleared
                    while (clearedTokenIds[baseTokenId] != false) {
                        baseTokenId = (++baseTokenId) % 100;
                    }

                    delete tokenRecipient[baseTokenId];
                    clearedTokenIds[baseTokenId] = true;

                    emit MintUnscheduled(baseTokenId, i, cachedFounder);

                    // Update the base token id
                    baseTokenId = (baseTokenId + schedule) % 100;
                }
            }
        }

        // Clear values from storage before adding new founders
        settings.numFounders = 0;
        settings.totalOwnership = 0;
        emit FounderAllocationsCleared(newFounders);

        _addFounders(newFounders, reservedUntilTokenId);
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

    /// @notice The contract owner
    function owner() public view override(IBaseToken, Ownable) returns (address) {
        return super.owner();
    }

    /// @notice Update minters
    /// @param _minters Array of structs containing address status as a minter
    function updateMinters(MinterParams[] calldata _minters) external onlyOwner {
        // Update each minter
        for (uint256 i; i < _minters.length; ++i) {
            // Skip if the minter is already set to the correct value
            if (minter[_minters[i].minter] == _minters[i].allowed) continue;

            emit MinterUpdated(_minters[i].minter, _minters[i].allowed);

            // Update the minter
            minter[_minters[i].minter] = _minters[i].allowed;
        }
    }

    /// @notice Check if an address is a minter
    /// @param _minter Address to check
    function isMinter(address _minter) external view returns (bool) {
        return minter[_minter];
    }

    /// @notice Set a new metadata renderer
    /// @param newRenderer new renderer address to use
    function setMetadataRenderer(IBaseMetadata newRenderer) external {
        // Ensure the caller is the contract manager
        if (msg.sender != address(manager)) {
            revert ONLY_MANAGER();
        }

        settings.metadataRenderer = newRenderer;
    }

    ///                                                          ///
    ///                         ERC165                           ///
    ///                                                          ///

    function supportsInterface(bytes4 interfaceId) public pure virtual override returns (bool) {
        return interfaceId == type(IMirrorToken).interfaceId || super.supportsInterface(interfaceId);
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
