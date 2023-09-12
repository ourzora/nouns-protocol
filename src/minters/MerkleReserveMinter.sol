// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { IOwnable } from "../lib/interfaces/IOwnable.sol";
import { IToken } from "../token/default/IToken.sol";
import { IManager } from "../manager/IManager.sol";

/// @title MerkleReserveMinter
/// @notice Mints reserved tokens based on a merkle tree
/// @author @neokry
contract MerkleReserveMinter {
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

    /// @notice Event for mint settings updated
    event MinterSet(address indexed mediaContract, MerkleMinterSettings merkleSaleSettings);

    /// @notice Manager contract
    IManager immutable manager;

    /// @notice Mapping of DAO token contract to merkle settings
    mapping(address => MerkleMinterSettings) public allowedMerkles;

    error NOT_TOKEN_OWNER();
    error TRANSFER_FAILED();
    error MINT_ENDED();
    error MINT_NOT_STARTED();
    error INVALID_VALUE();
    error INVALID_CLAIM_COUNT();
    error INVALID_MERKLE_PROOF(address mintTo, bytes32[] merkleProof, bytes32 merkleRoot);

    /// @notice Checks if the caller is the contract owner
    /// @param tokenContract Token contract to check
    modifier onlyContractOwner(address tokenContract) {
        if (!_isContractOwner(tokenContract)) {
            revert NOT_TOKEN_OWNER();
        }
        _;
    }

    constructor(IManager _manager) {
        manager = _manager;
    }

    /// @notice Mints tokens from reserve using a merkle proof
    /// @param tokenContract Address of token contract
    /// @param claims List of merkle claims
    function mintFromReserve(address tokenContract, MerkleClaim[] calldata claims) public payable {
        MerkleMinterSettings memory settings = allowedMerkles[tokenContract];
        uint256 claimCount = claims.length;

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

        if (claimCount * settings.pricePerToken != msg.value) {
            revert INVALID_VALUE();
        }

        // Mint tokens
        unchecked {
            for (uint256 i = 0; i < claimCount; ++i) {
                MerkleClaim memory claim = claims[i];

                if (!MerkleProof.verify(claim.merkleProof, settings.merkleRoot, keccak256(abi.encode(claim.mintTo, claim.tokenId)))) {
                    revert INVALID_MERKLE_PROOF(claim.mintTo, claim.merkleProof, settings.merkleRoot);
                }

                IToken(tokenContract).mintFromReserveTo(claim.mintTo, claim.tokenId);
            }
        }

        // Transfer funds to treasury
        if (settings.pricePerToken > 0) {
            (, , address treasury, ) = manager.getAddresses(tokenContract);

            (bool success, ) = treasury.call{ value: msg.value }("");

            if (!success) {
                revert TRANSFER_FAILED();
            }
        }
    }

    /// @notice Sets the minter settings for a token
    /// @param tokenContract Token contract to set settings for
    /// @param merkleMinterSettings Settings to set
    function setSettings(address tokenContract, MerkleMinterSettings memory merkleMinterSettings) external onlyContractOwner(tokenContract) {
        allowedMerkles[tokenContract] = merkleMinterSettings;

        // Emit event for new settings
        emit MinterSet(tokenContract, merkleMinterSettings);
    }

    /// @notice Resets the minter settings for a token
    /// @param tokenContract Token contract to reset settings for
    function resetSettings(address tokenContract) external onlyContractOwner(tokenContract) {
        delete allowedMerkles[tokenContract];

        // Emit event with null settings
        emit MinterSet(tokenContract, allowedMerkles[tokenContract]);
    }

    function _isContractOwner(address tokenContract) internal view returns (bool) {
        return IOwnable(tokenContract).owner() == msg.sender;
    }
}
