// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

import {TimelockControllerUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IUpgradeManager} from "../../upgrades/IUpgradeManager.sol";
import {ITreasury} from "./ITreasury.sol";

/// @notice PLACEHOLDER FOR OpenZeppelin's `TimelockControllerUpgradeable`
/// @notice Modified version of NounsDAOExecutor.sol (commit 2cbe6c7) that NounsDAO licensed under the GPL-3.0 license
contract Treasury is UUPSUpgradeable, OwnableUpgradeable {
    ///                                                          ///
    ///                            CONSTANTS                     ///
    ///                                                          ///

    uint256 public constant GRACE_PERIOD = 14 days;

    uint256 public constant MINIMUM_DELAY = 2 days;

    uint256 public constant MAXIMUM_DELAY = 30 days;

    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    IUpgradeManager private immutable UpgradeManager;

    ///                                                          ///
    ///                           CONSTRUCTOR                    ///
    ///                                                          ///

    constructor(address _upgradeManager) payable initializer {
        UpgradeManager = IUpgradeManager(_upgradeManager);
        delay = 2 days;
    }

    receive() external payable {}

    fallback() external payable {}

    ///                                                          ///
    ///                             STORAGE                      ///
    ///                                                          ///

    address public admin;

    address public pendingAdmin;

    uint256 public delay;

    mapping(bytes32 => bool) public queuedTransactions;

    ///                                                          ///
    ///                           INITIALIZER                    ///
    ///                                                          ///

    function initialize(address _admin) public initializer {
        __UUPSUpgradeable_init();

        __Ownable_init();

        transferOwnership(_admin);

        admin = _admin;
    }

    ///                                                          ///
    ///                            TREASURY                      ///
    ///                                                          ///

    event NewDelay(uint256 indexed newDelay);

    function setDelay(uint256 delay_) public {
        require(msg.sender == address(this), "ONLY_TREASURY");
        require(delay_ >= MINIMUM_DELAY, "MUST_EXCEED_MIN_DELAY");
        require(delay_ <= MAXIMUM_DELAY, "CANNOT_EXCEED_MAX_DELAY");

        delay = delay_;

        emit NewDelay(delay);
    }

    event NewPendingAdmin(address indexed newPendingAdmin);

    function setPendingAdmin(address pendingAdmin_) public {
        require(msg.sender == address(this), "ONLY_TREASURY");

        pendingAdmin = pendingAdmin_;

        emit NewPendingAdmin(pendingAdmin);
    }

    ///                                                          ///
    ///                         PENDING ADMIN                    ///
    ///                                                          ///

    event NewAdmin(address indexed newAdmin);

    function acceptAdmin() public {
        require(msg.sender == pendingAdmin, "ONLY_PENDING_ADMIN");

        admin = msg.sender;

        delete pendingAdmin;

        emit NewAdmin(admin);
    }

    ///                                                          ///
    ///                             ADMIN                        ///
    ///                                                          ///

    event QueueTransaction(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta);

    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public returns (bytes32) {
        require(msg.sender == admin, "ONLY_ADMIN");
        require(eta >= block.timestamp + delay, "INVALID_ETA");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    event CancelTransaction(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta);

    function cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public {
        require(msg.sender == admin, "ONLY_ADMIN");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    event ExecuteTransaction(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta);

    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public returns (bytes memory) {
        require(msg.sender == admin, "ONLY_ADMIN");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));

        require(queuedTransactions[txHash], "TX_NOT_QUEUED");
        require(block.timestamp >= eta, "TX_BEHIND_TIMELOCK");
        require(block.timestamp <= eta + GRACE_PERIOD, "TX_STALE");

        queuedTransactions[txHash] = false;

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, "TX_REVERTED");

        emit ExecuteTransaction(txHash, target, value, signature, data, eta);

        return returnData;
    }

    ///                                                          ///
    ///                         PROXY UPGRADE                    ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract to a valid implementation
    /// @dev This function is called in UUPS `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The address of the new implementation
    function _authorizeUpgrade(address _newImpl) internal override onlyOwner {
        // Ensure the implementation is valid
        require(UpgradeManager.isValidUpgrade(_getImplementation(), _newImpl), "INVALID_UPGRADE");
    }
}
