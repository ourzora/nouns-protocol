// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

// import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
// import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// import {ERC721VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/draft-ERC721VotesUpgradeable.sol";

import {TokenStorageV1} from "./storage/TokenStorageV1.sol";
import {IMetadataRenderer} from "./metadata/IMetadataRenderer.sol";
import {IUpgradeManager} from "../upgrade/IUpgradeManager.sol";
import {IToken} from "./IToken.sol";

// /// @title Nounish ERC-721 Token
// /// @author Rohan Kulkarni
// /// @notice Modified version of NounsToken.sol (commit 2cbe6c7) that NounsDAO licensed under the GPL-3.0 license
// contract Token is UUPSUpgradeable, ReentrancyGuardUpgradeable, ERC721VotesUpgradeable, TokenStorageV1 {
//     ///                                                          ///
//     ///                          IMMUTABLES                      ///
//     ///                                                          ///

//     /// @notice The contract upgrade manager
//     IUpgradeManager private immutable upgradeManager;

//     /// @notice The Nouns Builder DAO address
//     address public immutable nounsBuilderDAO;

//     ///                                                          ///
//     ///                          CONSTRUCTOR                     ///
//     ///                                                          ///

//     /// @param _upgradeManager The address of the contract upgrade manager
//     /// @param _nounsBuilderDAO The address of the Nouns Builder DAO
//     constructor(address _upgradeManager, address _nounsBuilderDAO) payable initializer {
//         upgradeManager = IUpgradeManager(_upgradeManager);
//         nounsBuilderDAO = _nounsBuilderDAO;
//     }

//     ///                                                          ///
//     ///                          INITIALIZER                     ///
//     ///                                                          ///

//     /// @notice Initializes an ERC-1967 proxy instance of this token implementation
//     /// @param _init The encoded token and metadata initialization strings
//     /// @param _foundersDAO The address of the founders DAO
//     /// @param _foundersMaxTokens The maximum number of tokens the founders will vest (eg. 183 nouns to nounders)
//     /// @param _foundersAllocationFrequency The allocation frequency (eg. every 10 nouns)
//     /// @param _auction The address of the auction house that will mint tokens
//     function initialize(
//         bytes calldata _init,
//         address _metadataRenderer,
//         address _foundersDAO,
//         uint256 _foundersMaxTokens,
//         uint256 _foundersAllocationFrequency,
//         address _auction
//     ) public initializer {
//         // Initialize the reentrancy guard
//         __ReentrancyGuard_init();

//         // Decode the token initialization strings
//         (string memory _name, string memory _symbol, , , ) = abi.decode(_init, (string, string, string, string, string));

//         // Initialize the ERC-721 token
//         __ERC721_init(_name, _symbol);

//         // Store the founders' vesting details
//         founders.DAO = _foundersDAO;
//         founders.maxAllocation = uint32(_foundersMaxTokens);
//         founders.allocationFrequency = uint32(_foundersAllocationFrequency);

//         // Store the associated auction house
//         auction = _auction;

//         // Store the associated metadata renderer
//         metadataRenderer = IMetadataRenderer(_metadataRenderer);
//     }

//     ///                                                          ///
//     ///                              MINT                        ///
//     ///                                                          ///

//     /// @notice Mints tokens to the auction house for bidding and handles vesting to the founders & Nouns Builder DAO
//     function mint() public nonReentrant returns (uint256 tokenId) {
//         // Ensure the caller is the auction house
//         require(msg.sender == auction, "ONLY_AUCTION");

//         // Cannot realistically overflow uint32 or uint256 counters
//         unchecked {
//             // Get the next available token id
//             tokenId = totalSupply++;

//             // If the token is a vesting overlap between Nouns Builder DAO and the founders:
//             if (_isForNounsBuilderDAO(tokenId) && _isForFounders(tokenId)) {
//                 // Mint the token to Nouns Builder DAO
//                 _mint(nounsBuilderDAO, tokenId);

//                 // Get the next available token id
//                 tokenId = totalSupply++;

//                 // Update the number of tokens vested to the founders
//                 ++founders.currentAllocation;

//                 // Mint the next token to the founders
//                 _mint(founders.DAO, tokenId);

//                 // Get the next available token id
//                 tokenId = totalSupply++;

//                 // Else if the token is only for the founders:
//             } else if (_isForFounders(tokenId)) {
//                 // Update the number of tokens vested to the founders
//                 ++founders.currentAllocation;

//                 // Mint the token to the founders
//                 _mint(founders.DAO, tokenId);

//                 // Get the next available token id
//                 tokenId = totalSupply++;

//                 // Else if the token is only for Nouns Builder DAO:
//             } else if (_isForNounsBuilderDAO(tokenId)) {
//                 // Mint the token to Nouns Builder DAO
//                 _mint(nounsBuilderDAO, tokenId);

//                 // Get the next available token id
//                 tokenId = totalSupply++;
//             }
//         }

//         // Mint the next token to the auction house for bidding
//         _mint(auction, tokenId);

//         return tokenId;
//     }

//     /// @dev If a token meets the Nouns Builder DAO vesting schedule
//     /// @param _tokenId The ERC-721 token id
//     function _isForNounsBuilderDAO(uint256 _tokenId) private pure returns (bool vest) {
//         assembly {
//             vest := iszero(mod(add(_tokenId, 1), 100))
//         }
//     }

//     /// @dev If a token meets the founders' vesting schedule
//     /// @param _tokenId The ERC-721 token id
//     function _isForFounders(uint256 _tokenId) private view returns (bool vest) {
//         uint256 numVested = founders.currentAllocation;
//         uint256 vestingTotal = founders.maxAllocation;
//         uint256 vestingSchedule = founders.allocationFrequency;

//         assembly {
//             vest := and(lt(numVested, vestingTotal), iszero(mod(_tokenId, vestingSchedule)))
//         }
//     }

//     /// @dev Overrides _mint to include attribute generation
//     /// @param _to The token recipient
//     /// @param _tokenId The ERC-721 token id
//     function _mint(address _to, uint256 _tokenId) internal override {
//         // Mint the token
//         super._mint(_to, _tokenId);

//         // Generate the token attributes
//         metadataRenderer.generate(_tokenId);
//     }

//     ///                                                          ///
//     ///                             BURN                         ///
//     ///                                                          ///

//     /// @notice Burns a token that did not see any bids
//     /// @param _tokenId The ERC-721 token id
//     function burn(uint256 _tokenId) public {
//         // Ensure the caller is the auction house
//         require(msg.sender == auction, "ONLY_AUCTION");

//         // Burn the token
//         _burn(_tokenId);
//     }

//     ///                                                          ///
//     ///                              URI                         ///
//     ///                                                          ///

//     /// @notice The URI for the given token
//     /// @param _tokenId The ERC-721 token id
//     function tokenURI(uint256 _tokenId) public view override returns (string memory) {
//         return metadataRenderer.tokenURI(_tokenId);
//     }

//     /// @notice The URI for the contract
//     function contractURI() public view returns (string memory) {
//         return metadataRenderer.contractURI();
//     }

//     ///                                                          ///
//     ///                          FOUNDERS DAO                    ///
//     ///                                                          ///

//     /// @notice Emitted when the founders DAO is updated
//     /// @param foundersDAO The updated address of the founders DAO
//     event FoundersDAOUpdated(address foundersDAO);

//     /// @notice Updates the address of the founders DAO
//     /// @param _foundersDAO The address of the founders DAO to set
//     function setFoundersDAO(address _foundersDAO) external {
//         // Ensure the caller is the founders DAO
//         require(msg.sender == founders.DAO, "ONLY_FOUNDERS");

//         // Update the founders DAO address
//         founders.DAO = _foundersDAO;

//         emit FoundersDAOUpdated(_foundersDAO);
//     }

//     /// @notice Emitted when the founders vesting total is updated
//     /// @param numTokens The updated number of tokens to vest to the founders DAO
//     event FoundersVestingAllocation(uint256 numTokens);

//     /// @notice Updates the total number of tokens that will be vested to the founders DAO
//     /// @param _numTokens The number of tokens
//     function setFoundersVestingAllocation(uint256 _numTokens) external onlyOwner {
//         // Update the vesting total
//         founders.maxAllocation = uint32(_numTokens);

//         emit FoundersVestingAllocation(_numTokens);
//     }

//     /// @notice Emitted when the founders vesting schedule is updated
//     /// @param numTokens The gap between tokens vested to the founders DAO
//     event FoundersVestingSchedule(uint256 numTokens);

//     /// @notice Updates the gap between tokens that will be vested to the founders DAO
//     /// @param _numTokens The number of tokens
//     function setFoundersVestingSchedule(uint256 _numTokens) external onlyOwner {
//         // Update the vesting schedule
//         founders.allocationFrequency = uint32(_numTokens);

//         emit FoundersVestingSchedule(_numTokens);
//     }

//     /// @notice Called by the auction house upon bid settlement to auto-delegate the winner their vote
//     /// @param _user The address of the winning bidder
//     function autoDelegate(address _user) external {
//         // Ensure the caller is the auction house
//         require(msg.sender == auction, "ONLY_AUCTION");

//         // Delegate the winning bidder's voting unit to themselves
//         _delegate(_user, _user);
//     }

//     ///                                                          ///
//     ///                             OWNER                        ///
//     ///                                                          ///

//     /// @dev Ensures the caller is the contract owner
//     modifier onlyOwner() {
//         require(msg.sender == metadataRenderer.owner(), "ONLY_OWNER");
//         _;
//     }

//     /// @notice Returns the address of the contract owner
//     function owner() external view returns (address) {
//         return metadataRenderer.owner();
//     }

//     ///                                                          ///
//     ///                         PROXY UPGRADE                    ///
//     ///                                                          ///

//     /// @notice Ensures the caller is authorized to upgrade the contract to a valid implementation
//     /// @dev This function is called in UUPS `upgradeTo` & `upgradeToAndCall`
//     /// @param _newImpl The address of the new implementation
//     function _authorizeUpgrade(address _newImpl) internal override onlyOwner {
//         // Ensure the implementation is valid
//         require(upgradeManager.isValidUpgrade(_getImplementation(), _newImpl), "INVALID_UPGRADE");
//     }
// }

import {UUPS} from "../lib/proxy/UUPS.sol";
import {Ownable} from "../lib/utils/Ownable.sol";
import {ReentrancyGuard} from "../lib/utils/ReentrancyGuard.sol";
import {ECDSA} from "../lib/utils/ECDSA.sol";
import {EIP712} from "../lib/utils/EIP712.sol";
import {ERC721} from "../lib/token/ERC721.sol";

contract ERC721VotesTypesV1 {
    struct Checkpoint {
        uint64 timestamp;
        uint192 votes;
    }
}

contract ERC721VotesStorageV1 is ERC721VotesTypesV1 {
    mapping(address => mapping(uint256 => Checkpoint)) public checkpoints;

    mapping(address => uint256) public numCheckpoints;

    mapping(address => address) public delegates;

    mapping(address => uint256) internal nonces;
}

abstract contract ERC721Votes is EIP712, ERC721, ERC721VotesStorageV1 {
    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    bytes32 internal constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    /// @dev Emitted when an account changes their delegate.
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /// @dev Emitted when a token transfer or delegate change results in changes to a delegate's number of votes
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

    /// @dev Delegates votes from the sender to `_delegatee`
    function delegate(address _delegatee) public virtual {
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
    ) public virtual {
        require(block.timestamp <= expiry, "EXPIRED_SIG");

        address signer = ECDSA.recover(_hashTypedDataV4(keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry))), v, r, s);

        unchecked {
            require(nonce == nonces[signer]++, "INVALID_NONCE");
        }

        _delegate(signer, delegatee);
    }

    /// @dev Delegate all of `account`'s voting units to `delegatee`.
    function _delegate(address _account, address _delegatee) internal virtual {
        address prevDelegate = delegates[_account];

        delegates[_account] = _delegatee;

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
    ) internal virtual override {
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
    function getPastVotes(address _account, uint256 _timestamp) public view virtual returns (uint256) {
        // Ensure the given timestamp is in the past
        require(_timestamp < block.timestamp, "INVALID_TIMESTAMP");

        // Get the number of checkpoints for the account
        uint256 nCheckpoints = numCheckpoints[_account];

        // Return 0 if the account has none
        if (nCheckpoints == 0) return 0;

        // Get storage pointer
        // mapping(uint256 => Checkpoint) storage checkpoints = checkpoints[_account];

        // Return 0 if their first checkpoint is for a timestamp greater than the argument provided
        if (checkpoints[_account][0].timestamp > _timestamp) return 0;

        unchecked {
            // If their last recorded checkpoint is before the given timestamp, return its number of votes
            if (checkpoints[_account][nCheckpoints - 1].timestamp <= _timestamp) return checkpoints[_account][nCheckpoints - 1].votes;

            uint256 high = nCheckpoints - 1;

            uint256 low;

            uint256 avg;

            Checkpoint memory cp;

            while (high > low) {
                avg = (low & high) + (low ^ high) / 2;

                cp = checkpoints[_account][avg];

                if (cp.timestamp == _timestamp) {
                    return cp.votes;
                } else if (cp.timestamp < _timestamp) {
                    low = avg;
                } else {
                    high = avg - 1;
                }
            }

            return checkpoints[_account][low].votes;
        }
    }
}

contract Token is UUPS, ReentrancyGuard, ERC721Votes, TokenStorageV1 {
    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IUpgradeManager private immutable upgradeManager;

    /// @notice The Nouns Builder DAO address
    address public immutable nounsBuilderDAO;

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    /// @param _upgradeManager The address of the contract upgrade manager
    /// @param _nounsBuilderDAO The address of the Nouns Builder DAO
    constructor(address _upgradeManager, address _nounsBuilderDAO) payable initializer {
        upgradeManager = IUpgradeManager(_upgradeManager);
        nounsBuilderDAO = _nounsBuilderDAO;
    }

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

            // If the token is a vesting overlap between Nouns Builder DAO and the founders:
            if (_isForNounsBuilderDAO(tokenId) && _isForFounders(tokenId)) {
                // Mint the token to Nouns Builder DAO
                _mint(nounsBuilderDAO, tokenId);

                // Get the next available token id
                tokenId = totalSupply++;

                // Update the number of tokens vested to the founders
                ++founders.currentAllocation;

                // Mint the next token to the founders
                _mint(founders.DAO, tokenId);

                // Get the next available token id
                tokenId = totalSupply++;

                // Else if the token is only for the founders:
            } else if (_isForFounders(tokenId)) {
                // Update the number of tokens vested to the founders
                ++founders.currentAllocation;

                // Mint the token to the founders
                _mint(founders.DAO, tokenId);

                // Get the next available token id
                tokenId = totalSupply++;

                // Else if the token is only for Nouns Builder DAO:
            } else if (_isForNounsBuilderDAO(tokenId)) {
                // Mint the token to Nouns Builder DAO
                _mint(nounsBuilderDAO, tokenId);

                // Get the next available token id
                tokenId = totalSupply++;
            }
        }

        // Mint the next token to the auction house for bidding
        _mint(auction, tokenId);

        return tokenId;
    }

    /// @dev If a token meets the Nouns Builder DAO vesting schedule
    /// @param _tokenId The ERC-721 token id
    function _isForNounsBuilderDAO(uint256 _tokenId) private pure returns (bool vest) {
        assembly {
            vest := iszero(mod(add(_tokenId, 1), 100))
        }
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
    function contractURI() public view override returns (string memory) {
        return metadataRenderer.contractURI();
    }

    modifier onlyOwner() {
        require(msg.sender == metadataRenderer.owner(), "");
        _;
    }

    /// @notice Returns the address of the contract owner
    function owner() external view returns (address) {
        return metadataRenderer.owner();
    }

    // /// @notice Called by the auction house upon bid settlement to auto-delegate the winner their vote
    // /// @param _user The address of the winning bidder
    // function autoDelegate(address _user) external {
    //     // Ensure the caller is the auction house
    //     require(msg.sender == auction, "ONLY_AUCTION");

    //     // Delegate the winning bidder's voting unit to themselves
    //     _delegate(_user, _user);
    // }

    function _authorizeUpgrade(address _newImpl) internal override onlyOwner {}
}
