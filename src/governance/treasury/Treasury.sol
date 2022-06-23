// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {TimelockControllerUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IUpgradeManager} from "../../upgrade/IUpgradeManager.sol";
import {ITreasury} from "./ITreasury.sol";

/// @title Treasury
/// @author Rohan Kulkarni
/// @notice Modified version of NounsDAOExecutor.sol (commit 2cbe6c7) that NounsDAO licensed under the GPL-3.0 license
contract Treasury is TimelockControllerUpgradeable, UUPSUpgradeable {
    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    IUpgradeManager private immutable UpgradeManager;

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    constructor(address _upgradeManager) payable initializer {
        UpgradeManager = IUpgradeManager(_upgradeManager);
    }

    ///                                                          ///
    ///                          INITIALIZER                     ///
    ///                                                          ///

    ///
    ///
    ///
    function initialize(address _governor, uint256 _minDelay) public initializer {
        //
        address[] memory timelockUser = new address[](1);

        //
        timelockUser[0] = _governor;

        //
        __TimelockController_init(_minDelay, timelockUser, timelockUser);

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
        require(UpgradeManager.isValidUpgrade(_getImplementation(), _newImpl), "INVALID_UPGRADE");
    }
}
