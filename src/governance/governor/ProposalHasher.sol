// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title ProposalHasher
/// @author tbtstl
/// @notice Helper contract to ensure proposal hashing functions are unified
abstract contract ProposalHasher {
    ///                                                          ///
    ///                         HASH PROPOSAL                    ///
    ///                                                          ///

    /// @notice Hashes a proposal's details into a proposal id
    /// @param _targets The target addresses to call
    /// @param _values The ETH values of each call
    /// @param _calldatas The calldata of each call
    /// @param _descriptionHash The hash of the description
    /// @param _proposer The original proposer of the transaction
    function hashProposal(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash,
        address _proposer
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(_targets, _values, _calldatas, _descriptionHash, _proposer));
    }
}
