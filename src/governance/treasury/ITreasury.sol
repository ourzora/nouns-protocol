// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

interface ITreasury {
    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function initialize(address governor, uint256 timelockDelay) external;

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///
    function getMinDelay() external view returns (uint256);

    function isOperation(bytes32 id) external view returns (bool);

    function isOperationPending(bytes32 id) external view returns (bool);

    function isOperationReady(bytes32 id) external view returns (bool);

    function isOperationDone(bytes32 id) external view returns (bool);

    function getTimestamp(bytes32 id) external view returns (uint256);

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function updateDelay(uint256 newDelay) external;

    function hashOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) external pure returns (bytes32 hash);

    function hashOperationBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt
    ) external pure returns (bytes32 hash);

    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external;

    function scheduleBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external;

    function cancel(bytes32 id) external;

    function execute(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) external payable;

    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt
    ) external payable;

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function TIMELOCK_ADMIN_ROLE() external pure returns (bytes32);

    function PROPOSER_ROLE() external pure returns (bytes32);

    function EXECUTOR_ROLE() external pure returns (bytes32);

    function CANCELLER_ROLE() external pure returns (bytes32);

    function hasRole(bytes32 role, address account) external view returns (bool);

    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    function grantRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

    function renounceRole(bytes32 role, address account) external;

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function upgradeTo(address newImplementation) external;

    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
}
