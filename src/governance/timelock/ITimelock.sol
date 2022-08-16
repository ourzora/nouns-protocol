// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

interface ITimelock {
    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    event TransactionScheduled(uint256 proposalId, uint256 timestamp);

    event TransactionCanceled(uint256 proposalId);

    event TransactionExecuted(uint256 proposalId, address[] targets, uint256[] values, bytes[] payloads);

    event TransactionDelayUpdated(uint256 prevDelay, uint256 newDelay);

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    error ALREADY_QUEUED(uint256 proposalId);

    error NOT_QUEUED(uint256 proposalId);

    error TRANSACTION_NOT_READY(uint256 proposalId);

    error TRANSACTION_FAILED(address target, uint256 value, bytes data);

    error ONLY_TIMELOCK();

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function initialize(address governor, uint256 txDelay) external;

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    // function isOperation(uint256 proposalId) external view returns (bool);

    // function isOperationPending(uint256 proposalId) external view returns (bool);

    // function isOperationReady(uint256 proposalId) external view returns (bool);

    // function isOperationDone(uint256 proposalId) external view returns (bool);

    // function isOperationExpired(uint256 proposalId) external view returns (bool);

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function hashProposal(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        bytes32 descriptionHash
    ) external pure returns (uint256);

    function cancel(uint256 proposalId) external;

    // function schedule(
    //     address target,
    //     uint256 value,
    //     bytes calldata data,
    //     bytes32 predecessor,
    //     bytes32 salt,
    //     uint256 delay
    // ) external;

    // function scheduleBatch(
    //     address[] calldata targets,
    //     uint256[] calldata values,
    //     bytes[] calldata payloads,
    //     bytes32 predecessor,
    //     bytes32 salt,
    //     uint256 delay
    // ) external;

    // function execute(
    //     address target,
    //     uint256 value,
    //     bytes calldata data,
    //     bytes32 predecessor,
    //     bytes32 salt
    // ) external payable;

    // function executeBatch(
    //     address[] calldata targets,
    //     uint256[] calldata values,
    //     bytes[] calldata payloads,
    //     bytes32 predecessor,
    //     bytes32 salt
    // ) external payable;

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function updateDelay(uint256 newDelay) external;
}
