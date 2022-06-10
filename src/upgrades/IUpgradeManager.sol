// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

/// @title IUpgradeManager
/// @author kulkarohan
/// @notice Interface for UpgradeManager
interface IUpgradeManager {
    /// @notice If an upgraded implementation has been registered for its original implementation
    /// @param _prevImpl The address of the original implementation
    /// @param _newImpl The address of the upgraded implementation
    function isValidUpgrade(address _prevImpl, address _newImpl) external returns (bool);
}
