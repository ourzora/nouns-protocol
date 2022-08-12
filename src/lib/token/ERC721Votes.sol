// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {ECDSA} from "../utils/ECDSA.sol";
import {EIP712} from "../utils/EIP712.sol";
import {ERC721} from "../token/ERC721.sol";

contract ERC721VotesTypesV1 {
    struct Checkpoint {
        uint64 timestamp;
        uint192 votes;
    }
}

contract ERC721VotesStorageV1 is ERC721VotesTypesV1 {
    mapping(address => mapping(uint256 => Checkpoint)) public checkpoints;

    mapping(address => uint256) public numCheckpoints;

    mapping(address => address) internal delegation;

    mapping(address => uint256) internal nonces;
}

abstract contract ERC721Votes is EIP712, ERC721, ERC721VotesStorageV1 {
    bytes32 internal constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    /// @dev Emitted when an account changes their delegate.
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /// @dev Emitted when a token transfer or delegate change results in changes to a delegate's number of votes
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

    function delegates(address _account) external view returns (address) {
        address current = delegation[_account];
        return current == address(0) ? _account : current;
    }

    /// @dev Delegates votes from the sender to `_delegatee`
    function delegate(address _delegatee) external {
        _delegate(msg.sender, _delegatee);
    }

    ///
    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp <= expiry, "EXPIRED_SIG");

        address signer = ECDSA.recover(_hashTypedDataV4(keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry))), v, r, s);

        unchecked {
            require(nonce == nonces[signer]++, "INVALID_NONCE");
        }

        _delegate(signer, delegatee);
    }

    /// @dev Delegate all of `account`'s voting units to `delegatee`.
    function _delegate(address _account, address _delegatee) internal {
        address prevDelegate = delegation[_account];

        delegation[_account] = _delegatee;

        emit DelegateChanged(_account, prevDelegate, _delegatee);

        _moveDelegateVotes(prevDelegate, _delegatee, balanceOf(_account));
    }

    /// @dev Moves delegated votes from one delegate to another.
    function _moveDelegateVotes(
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        unchecked {
            if (_from != _to && _amount > 0) {
                if (_from != address(0)) {
                    uint256 nCheckpoints = numCheckpoints[_from]++;

                    uint256 prevTotalVotes;

                    if (nCheckpoints != 0) {
                        prevTotalVotes = checkpoints[_from][nCheckpoints - 1].votes;
                    }

                    uint256 newTotalVotes = prevTotalVotes - _amount;

                    Checkpoint storage checkpoint = checkpoints[_from][nCheckpoints];

                    checkpoint.votes = uint192(newTotalVotes);
                    checkpoint.timestamp = uint64(block.timestamp);

                    emit DelegateVotesChanged(_from, prevTotalVotes, newTotalVotes);
                }

                if (_to != address(0)) {
                    uint256 nCheckpoints = numCheckpoints[_to]++;

                    uint256 prevTotalVotes;

                    if (nCheckpoints != 0) {
                        prevTotalVotes = checkpoints[_to][nCheckpoints - 1].votes;
                    }

                    uint256 newTotalVotes = prevTotalVotes + _amount;

                    Checkpoint storage checkpoint = checkpoints[_to][nCheckpoints];

                    checkpoint.votes = uint192(newTotalVotes);
                    checkpoint.timestamp = uint64(block.timestamp);

                    emit DelegateVotesChanged(_to, prevTotalVotes, newTotalVotes);
                }
            }
        }
    }

    function _afterTokenTransfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) internal override {
        _moveDelegateVotes(_from, _to, 1);

        super._afterTokenTransfer(_from, _to, _tokenId);
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    /// @notice The current amount of votes that `_account` has.
    function getVotes(address _account) public view returns (uint256) {
        uint256 nCheckpoints = numCheckpoints[_account];

        unchecked {
            return nCheckpoints != 0 ? checkpoints[_account][nCheckpoints - 1].votes : 0;
        }
    }

    /// @notice Returns the amount of votes that `_account` had at the end of a past timestamp.
    function getPastVotes(address _account, uint256 _timestamp) public view returns (uint256) {
        require(_timestamp < block.timestamp, "INVALID_TIMESTAMP");

        uint256 nCheckpoints = numCheckpoints[_account];

        if (nCheckpoints == 0) return 0;

        mapping(uint256 => Checkpoint) storage accountCheckpoints = checkpoints[_account];

        if (accountCheckpoints[0].timestamp > _timestamp) return 0;

        unchecked {
            if (accountCheckpoints[nCheckpoints - 1].timestamp <= _timestamp) return accountCheckpoints[nCheckpoints - 1].votes;

            uint256 high = nCheckpoints - 1;

            uint256 low;

            uint256 avg;

            Checkpoint memory tempCP;

            while (high > low) {
                avg = (low & high) + (low ^ high) / 2;

                tempCP = accountCheckpoints[avg];

                if (tempCP.timestamp == _timestamp) {
                    return tempCP.votes;
                } else if (tempCP.timestamp < _timestamp) {
                    low = avg;
                } else {
                    high = avg - 1;
                }
            }

            return accountCheckpoints[low].votes;
        }
    }
}
