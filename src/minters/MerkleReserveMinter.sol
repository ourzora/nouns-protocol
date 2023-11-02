// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { IOwnable } from "../lib/interfaces/IOwnable.sol";
import { IToken } from "../token/IToken.sol";
import { Manager } from "../manager/Manager.sol";
import { IProtocolRewards } from "../lib/interfaces/IProtocolRewards.sol";

/// @title MerkleReserveMinter
/// @notice A mint strategy that mints reserved tokens based on a merkle tree
/// @author @neokry
contract MerkleReserveMinter {
    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    /// @notice Event for mint settings updated
    event MinterSet(address indexed tokenContract, MerkleMinterSettings merkleSaleSettings);

    ///                                                          ///
    ///                            ERRORS                        ///
    ///                                                          ///

    /// @dev Caller is not the owner of the specified token contract
    error NOT_TOKEN_OWNER();

    /// @dev Transfer failed
    error TRANSFER_FAILED();

    /// @dev Mint has ended
    error MINT_ENDED();

    /// @dev Mint has not started
    error MINT_NOT_STARTED();

    /// @dev Value sent does not match total fee value
    error INVALID_VALUE();

    /// @dev Invalid amount of tokens to claim
    error INVALID_CLAIM_COUNT();

    /// @dev Merkle proof for claim is invalid
    /// @param mintTo Address to mint to
    /// @param merkleProof Merkle proof for token
    /// @param merkleRoot Merkle root for collection
    error INVALID_MERKLE_PROOF(address mintTo, bytes32[] merkleProof, bytes32 merkleRoot);

    ///                                                          ///
    ///                            STRUCTS                       ///
    ///                                                          ///

    /// @notice General merkle sale settings
    struct MerkleMinterSettings {
        /// @notice Unix timestamp for the mint start
        uint64 mintStart;
        /// @notice Unix timestamp for the mint end
        uint64 mintEnd;
        /// @notice Price per token
        uint64 pricePerToken;
        /// @notice Merkle root for
        bytes32 merkleRoot;
    }

    /// @notice Parameters for merkle minting
    struct MerkleClaim {
        /// @notice Address to mint to
        address mintTo;
        /// @notice Token ID to mint
        uint256 tokenId;
        /// @notice Merkle proof for token
        bytes32[] merkleProof;
    }

    ///                                                          ///
    ///                            CONSTANTS                     ///
    ///                                                          ///

    /// @notice Per token mint fee sent to BuilderDAO
    uint256 public constant BUILDER_DAO_FEE = 0.000777 ether;

    ///                                                          ///
    ///                            IMMUTABLES                    ///
    ///                                                          ///

    /// @notice Manager contract
    Manager immutable manager;

    /// @notice Protocol rewards contract
    IProtocolRewards immutable protocolRewards;

    ///                                                          ///
    ///                            STORAGE                       ///
    ///                                                          ///

    /// @notice Mapping of DAO token contract to merkle settings
    mapping(address => MerkleMinterSettings) public allowedMerkles;

    ///                                                          ///
    ///                            MODIFIERS                     ///
    ///                                                          ///

    /// @notice Checks if the caller is the token contract or the owner of the token contract
    /// @param tokenContract Token contract to check
    modifier onlyContractOwner(address tokenContract) {
        // Revert if sender is not the token contract owner
        if (!_isContractOwner(msg.sender, tokenContract)) {
            revert NOT_TOKEN_OWNER();
        }
        _;
    }

    ///                                                          ///
    ///                            CONSTRUCTOR                   ///
    ///                                                          ///

    constructor(address _manager, address _protocolRewards) {
        manager = Manager(_manager);
        protocolRewards = IProtocolRewards(_protocolRewards);
    }

    ///                                                          ///
    ///                            MINT                          ///
    ///                                                          ///

    /// @notice Mints tokens from reserve using a merkle proof
    /// @param tokenContract Address of token contract
    /// @param claims List of merkle claims
    function mintFromReserve(address tokenContract, MerkleClaim[] calldata claims) public payable {
        MerkleMinterSettings memory settings = allowedMerkles[tokenContract];
        uint256 claimCount = claims.length;

        // Ensure claims are not empty
        if (claimCount == 0) {
            revert INVALID_CLAIM_COUNT();
        }

        // Check sale end
        if (block.timestamp > settings.mintEnd) {
            revert MINT_ENDED();
        }

        // Check sale start
        if (block.timestamp < settings.mintStart) {
            revert MINT_NOT_STARTED();
        }

        // Check value sent
        if (msg.value < _getTotalFeesForMint(settings.pricePerToken, claimCount)) {
            revert INVALID_VALUE();
        }

        // Mint tokens
        unchecked {
            for (uint256 i = 0; i < claimCount; ++i) {
                // Load claim in memory
                MerkleClaim memory claim = claims[i];

                // Requires one proof per tokenId to handle cases where users want to partially claim
                if (!MerkleProof.verify(claim.merkleProof, settings.merkleRoot, keccak256(abi.encode(claim.mintTo, claim.tokenId)))) {
                    revert INVALID_MERKLE_PROOF(claim.mintTo, claim.merkleProof, settings.merkleRoot);
                }

                // Only allowing reserved tokens to be minted for this strategy
                IToken(tokenContract).mintFromReserveTo(claim.mintTo, claim.tokenId);
            }
        }

        // Distribute fees if minting fees for this collection are set (Builder DAO fee does not apply to free mints)
        if (settings.pricePerToken > 0) {
            _distributeFees(tokenContract, claimCount);
        }
    }

    ///                                                          ///
    ///                            FEES                          ///
    ///                                                          ///

    /// @notice gets the total fees for minting
    function getTotalFeesForMint(address tokenContract, uint256 quantity) public view returns (uint256) {
        return _getTotalFeesForMint(allowedMerkles[tokenContract].pricePerToken, quantity);
    }

    function _getTotalFeesForMint(uint256 pricePerToken, uint256 quantity) internal pure returns (uint256) {
        // If pricePerToken is 0 the mint has no Builder DAO fee
        return pricePerToken > 0 ? quantity * (pricePerToken + BUILDER_DAO_FEE) : 0;
    }

    function _distributeFees(address tokenContract, uint256 quantity) internal {
        uint256 builderFee = quantity * BUILDER_DAO_FEE;
        uint256 value = msg.value;

        (, , address treasury, ) = manager.getAddresses(tokenContract);
        address builderRecipient = manager.builderRewardsRecipient();

        // Pay out fees to the Builder DAO
        protocolRewards.deposit{ value: builderFee }(builderRecipient, hex"00", "");

        // Pay out remaining funds to the treasury
        if (value > builderFee) {
            (bool treasurySuccess, ) = treasury.call{ value: value - builderFee }("");

            // Revert if treasury cannot accept funds
            if (!treasurySuccess) {
                revert TRANSFER_FAILED();
            }
        }
    }

    ///                                                          ///
    ///                            Settings                      ///

    /// @notice Sets the minter settings for a token
    /// @param tokenContract Token contract to set settings for
    /// @param settings Settings to set
    function setMintSettings(address tokenContract, MerkleMinterSettings memory settings) external onlyContractOwner(tokenContract) {
        // Set new collection settings
        _setMintSettings(tokenContract, settings);

        // Emit event for new settings
        emit MinterSet(tokenContract, settings);
    }

    /// @notice Resets the minter settings for a token
    /// @param tokenContract Token contract to reset settings for
    function resetMintSettings(address tokenContract) external onlyContractOwner(tokenContract) {
        // Reset collection settings to null
        delete allowedMerkles[tokenContract];

        // Emit event with null settings
        emit MinterSet(tokenContract, allowedMerkles[tokenContract]);
    }

    function _setMintSettings(address tokenContract, MerkleMinterSettings memory settings) internal {
        allowedMerkles[tokenContract] = settings;
    }

    ///                                                          ///
    ///                            Ownership                     ///
    ///                                                          ///

    function _isContractOwner(address caller, address tokenContract) internal view returns (bool) {
        return IOwnable(tokenContract).owner() == caller;
    }
}
