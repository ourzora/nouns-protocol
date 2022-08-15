// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {UUPS} from "../../lib/proxy/UUPS.sol";
import {Ownable} from "../../lib/utils/Ownable.sol";
import {ERC721TokenReceiver, ERC1155TokenReceiver} from "../../lib/utils/TokenReceiver.sol";

import {TimelockStorageV1} from "./storage/TimelockStorageV1.sol";
import {ITimelock} from "./ITimelock.sol";
import {IManager} from "../../manager/IManager.sol";

/// @title Timelock
/// @author Rohan Kulkarni
/// @notice This contract represents a DAO treasury that is controlled by a governor
contract Timelock is ITimelock, UUPS, Ownable, TimelockStorageV1 {
    ///                                                          ///
    ///                         CONSTANTS                        ///
    ///                                                          ///

    /// @notice The amount of time to execute an eligible transaction
    uint256 public constant GRACE_PERIOD = 2 weeks;

    /// @dev The timestamp denoting an executed transaction
    uint256 internal constant EXECUTED = 1;

    ///                                                          ///
    ///                         IMMUTABLES                       ///
    ///                                                          ///

    /// @dev The contract upgrade manager
    IManager private immutable manager;

    ///                                                          ///
    ///                         CONSTRUCTOR                      ///
    ///                                                          ///

    /// @param _manager The address of the contract upgrade manager
    constructor(address _manager) payable initializer {
        manager = IManager(_manager);
    }

    ///                                                          ///
    ///                         INITIALIZER                      ///
    ///                                                          ///

    /// @notice Initializes an instance of the timelock
    /// @param _governor The address of the governor
    /// @param _delay The time delay
    function initialize(address _governor, uint256 _delay) external initializer {
        // Ensure the zero address was not
        if (_governor == address(0)) revert INVALID_INIT();

        // Grant ownership to the governor
        __Ownable_init(_governor);

        // Store the
        delay = _delay;

        emit TransactionDelayUpdated(0, _delay);
    }

    ///                                                          ///
    ///                       TRANSACTION STATE                  ///
    ///                                                          ///

    /// @notice If a transaction was previously queued or executed
    /// @param _proposalId The proposal id
    function exists(uint256 _proposalId) public view returns (bool) {
        return timestamps[_proposalId] > 0;
    }

    /// @notice If a transaction is currently queued
    /// @param _proposalId The proposal id
    function isQueued(uint256 _proposalId) public view returns (bool) {
        return timestamps[_proposalId] > EXECUTED;
    }

    /// @notice If a transaction is ready to execute
    /// @param _proposalId The proposal id
    function isReadyToExecute(uint256 _proposalId) public view returns (bool) {
        return timestamps[_proposalId] > EXECUTED && timestamps[_proposalId] <= block.timestamp;
    }

    /// @notice If a transaction was executed
    /// @param _proposalId The proposal id
    function isExecuted(uint256 _proposalId) public view returns (bool) {
        return timestamps[_proposalId] == EXECUTED;
    }

    /// @notice If a transaction was not executed even after the grace period
    /// @param _proposalId The proposal id
    function isExpired(uint256 _proposalId) public view returns (bool) {
        unchecked {
            return block.timestamp > timestamps[_proposalId] + GRACE_PERIOD;
        }
    }

    ///                                                          ///
    ///                         HASH PROPOSAL                    ///
    ///                                                          ///

    /// @notice The proposal id
    function hashProposal(
        address[] calldata _targets,
        uint256[] calldata _values,
        bytes[] calldata _calldatas,
        bytes32 _descriptionHash
    ) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(_targets, _values, _calldatas, _descriptionHash)));
    }

    ///                                                          ///
    ///                         QUEUE PROPOSAL                   ///
    ///                                                          ///

    /// @notice Queues a proposal to be executed
    /// @param _proposalId The proposal id
    function schedule(uint256 _proposalId) external onlyOwner {
        // Ensure the proposal was not already queued
        if (exists(_proposalId)) revert ALREADY_QUEUED(_proposalId);

        // Used to store the timestamp the proposal will be valid to execute
        uint256 executionTime;

        // Cannot realistically overflow
        unchecked {
            // Add the timelock delay to the current time to get the valid time to execute
            executionTime = block.timestamp + delay;
        }

        // Store the execution timestamp
        timestamps[_proposalId] = executionTime;

        emit TransactionScheduled(_proposalId, executionTime);
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    /// @notice Removes a proposal that was canceled or vetoed
    /// @param _proposalId The proposal id
    function cancel(uint256 _proposalId) external onlyOwner {
        // Ensure the proposal is queued
        if (!isQueued(_proposalId)) revert NOT_QUEUED(_proposalId);

        // Remove the associated timestamp from storage
        delete timestamps[_proposalId];

        emit TransactionCanceled(_proposalId);
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function execute(
        address[] calldata _targets,
        uint256[] calldata _values,
        bytes[] calldata _calldatas,
        bytes32 _descriptionHash
    ) external payable onlyOwner {
        uint256 proposalId = hashProposal(_targets, _values, _calldatas, _descriptionHash);

        if (!isReadyToExecute(proposalId)) revert TRANSACTION_NOT_READY(proposalId);

        uint256 numTargets = _targets.length;

        for (uint256 i = 0; i < numTargets; ) {
            _execute(_targets[i], _values[i], _calldatas[i]);

            unchecked {
                ++i;
            }
        }

        timestamps[proposalId] = EXECUTED;

        emit TransactionExecuted(proposalId, _targets, _values, _calldatas);
    }

    function _execute(
        address _target,
        uint256 _value,
        bytes calldata _data
    ) internal {
        (bool success, ) = _target.call{value: _value}(_data);

        if (!success) revert TRANSACTION_FAILED(_target, _value, _data);
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function updateDelay(uint256 _newDelay) external {
        if (msg.sender != address(this)) revert ONLY_TIMELOCK();

        emit TransactionDelayUpdated(delay, _newDelay);

        delay = _newDelay;
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public pure returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public pure returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public pure returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }

    receive() external payable {}

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function _authorizeUpgrade(address _newImpl) internal view override onlyOwner {
        if (!manager.isValidUpgrade(_getImplementation(), _newImpl)) revert INVALID_UPGRADE(_newImpl);
    }
}
