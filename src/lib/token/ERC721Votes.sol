// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {EIP712} from "../utils/EIP712.sol";
import {ERC721} from "../token/ERC721.sol";

contract ERC721VotesTypesV1 {
    struct Checkpoint {
        uint64 timestamp;
        uint192 votes;
    }
}

contract ERC721VotesStorageV1 is ERC721VotesTypesV1 {
    mapping(address => uint256) public numCheckpoints;

    mapping(address => mapping(uint256 => Checkpoint)) public checkpoints;

    mapping(address => address) internal delegation;
}

abstract contract ERC721Votes is EIP712, ERC721, ERC721VotesStorageV1 {
    ///                                                          ///
    ///                           CONSTANTS                      ///
    ///                                                          ///

    bytes32 internal constant DELEGATION_TYPEHASH = keccak256("Delegation(address from,address to,uint256 nonce,uint256 deadline)");

    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    event DelegateChanged(address indexed delegator, address indexed from, address indexed to);

    event DelegateVotesChanged(address indexed delegate, uint256 prevVotes, uint256 newVotes);

    ///                                                          ///
    ///                            ERRORS                        ///
    ///                                                          ///

    error INVALID_TIMESTAMP();

    ///                                                          ///
    ///                           FUNCTIONS                      ///
    ///                                                          ///

    function delegates(address _user) external view returns (address) {
        address current = delegation[_user];

        return current == address(0) ? _user : current;
    }

    function delegate(address _to) external {
        _delegate(msg.sender, _to);
    }

    function delegateBySig(
        address _from,
        address _to,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        if (block.timestamp > _deadline) revert EXPIRED_SIGNATURE();

        bytes32 digest;

        unchecked {
            digest = keccak256(
                abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), keccak256(abi.encode(DELEGATION_TYPEHASH, _from, _to, nonces[_from]++, _deadline)))
            );
        }

        address recoveredAddress = ecrecover(digest, _v, _r, _s);

        if (recoveredAddress == address(0) || recoveredAddress != _from) revert INVALID_SIGNER();

        _delegate(_from, _to);
    }

    function _delegate(address _from, address _to) internal {
        address prevDelegate = delegation[_from];

        delegation[_from] = _to;

        emit DelegateChanged(_from, prevDelegate, _to);

        _moveDelegateVotes(prevDelegate, _to, balanceOf(_from));
    }

    function _moveDelegateVotes(
        address _from,
        address _to,
        uint256 _amount
    ) private {
        unchecked {
            if (_from != _to && _amount > 0) {
                if (_from != address(0)) {
                    uint256 nCheckpoints = numCheckpoints[_from]++;

                    uint256 prevTotalVotes;

                    if (nCheckpoints != 0) prevTotalVotes = checkpoints[_from][nCheckpoints - 1].votes;

                    _writeCheckpoint(_from, nCheckpoints, prevTotalVotes, prevTotalVotes - _amount);
                }

                if (_to != address(0)) {
                    uint256 nCheckpoints = numCheckpoints[_to]++;

                    uint256 prevTotalVotes;

                    if (nCheckpoints != 0) prevTotalVotes = checkpoints[_to][nCheckpoints - 1].votes;

                    _writeCheckpoint(_to, nCheckpoints, prevTotalVotes, prevTotalVotes + _amount);
                }
            }
        }
    }

    function _writeCheckpoint(
        address _user,
        uint256 _index,
        uint256 _prevTotalVotes,
        uint256 _newTotalVotes
    ) private {
        Checkpoint storage checkpoint = checkpoints[_user][_index];

        checkpoint.votes = uint192(_newTotalVotes);
        checkpoint.timestamp = uint64(block.timestamp);

        emit DelegateVotesChanged(_user, _prevTotalVotes, _newTotalVotes);
    }

    function getVotes(address _user) public view virtual returns (uint256) {
        uint256 nCheckpoints = numCheckpoints[_user];

        unchecked {
            return nCheckpoints != 0 ? checkpoints[_user][nCheckpoints - 1].votes : 0;
        }
    }

    function getPastVotes(address _user, uint256 _timestamp) public view returns (uint256) {
        if (_timestamp >= block.timestamp) revert INVALID_TIMESTAMP();

        uint256 nCheckpoints = numCheckpoints[_user];

        if (nCheckpoints == 0) return 0;

        mapping(uint256 => Checkpoint) storage userCheckpoints = checkpoints[_user];

        unchecked {
            uint256 lastCheckpoint = nCheckpoints - 1;

            if (userCheckpoints[lastCheckpoint].timestamp <= _timestamp) return userCheckpoints[lastCheckpoint].votes;

            if (userCheckpoints[0].timestamp > _timestamp) return 0;

            uint256 high = lastCheckpoint;

            uint256 low;

            uint256 avg;

            Checkpoint memory cp;

            while (high > low) {
                avg = (low & high) + (low ^ high) / 2;

                cp = userCheckpoints[avg];

                if (cp.timestamp == _timestamp) {
                    return cp.votes;
                } else if (cp.timestamp < _timestamp) {
                    low = avg;
                } else {
                    high = avg - 1;
                }
            }

            return userCheckpoints[low].votes;
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
}
