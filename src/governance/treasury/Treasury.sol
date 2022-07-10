// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {TimelockControllerUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IUpgradeManager} from "../../upgrade/IUpgradeManager.sol";
import {ITreasury} from "./ITreasury.sol";

/// @title Treasury
/// @author Rohan Kulkarni
/// @notice Modified version of NounsDAOExecutor.sol (commit 2cbe6c7) that NounsDAO licensed under the GPL-3.0 license
contract Treasury is UUPSUpgradeable, TimelockControllerUpgradeable {
    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    IUpgradeManager private immutable upgradeManager;

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    constructor(address _upgradeManager) payable initializer {
        upgradeManager = IUpgradeManager(_upgradeManager);
    }

    ///                                                          ///
    ///                          INITIALIZER                     ///
    ///                                                          ///

    ///
    ///
    ///
    function initialize(address _governor, uint256 _timelockDelay) public initializer {
        //
        address[] memory proposersAndExecutors = new address[](1);

        //
        proposersAndExecutors[0] = _governor;

        //
        __TimelockController_init(_timelockDelay, proposersAndExecutors, proposersAndExecutors);

        //
        _grantRole(TIMELOCK_ADMIN_ROLE, _governor);

        //
        _revokeRole(TIMELOCK_ADMIN_ROLE, msg.sender);
    }

    ///                                                          ///
    ///                         PROXY UPGRADE                    ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract to a valid implementation
    /// @dev This function is called in UUPS `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The address of the new implementation
    function _authorizeUpgrade(address _newImpl) internal override onlyRole(TIMELOCK_ADMIN_ROLE) {
        // Ensure the implementation is valid
        require(upgradeManager.isValidUpgrade(_getImplementation(), _newImpl), "INVALID_UPGRADE");
    }
}
