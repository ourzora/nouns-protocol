// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { IUUPS } from "../lib/interfaces/IUUPS.sol";
import { IOwnable } from "../lib/interfaces/IOwnable.sol";

/// @title IManager
/// @author Rohan Kulkarni
/// @notice The external Manager events, errors, structs and functions
interface IManager is IUUPS, IOwnable {
    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    /// @notice Emitted when a DAO is deployed
    /// @param token The ERC-721 token address
    /// @param metadata The metadata renderer address
    /// @param auction The auction address
    /// @param treasury The treasury address
    /// @param governor The governor address
    event DAODeployed(address token, address metadata, address auction, address treasury, address governor);

    /// @notice Emitted when an implementation is registered by the Builder DAO
    /// @param implType The type of implementation
    /// @param implAddress The implementation address
    event ImplementationRegistered(uint8 implType, address implAddress);

    /// @notice Emitted when an implementation is unregistered by the Builder DAO
    /// @param implType The type of implementation
    /// @param implAddress The implementation address
    event ImplemenetationRemoved(uint8 implType, address implAddress);

    /// @notice Emitted when an upgrade is registered by the Builder DAO
    /// @param baseImpl The base implementation address
    /// @param upgradeImpl The upgrade implementation address
    event UpgradeRegistered(address baseImpl, address upgradeImpl);

    /// @notice Emitted when an upgrade is unregistered by the Builder DAO
    /// @param baseImpl The base implementation address
    /// @param upgradeImpl The upgrade implementation address
    event UpgradeRemoved(address baseImpl, address upgradeImpl);

    ///                                                          ///
    ///                            ERRORS                        ///
    ///                                                          ///

    /// @dev Reverts if at least one founder is not provided upon deploy
    error FOUNDER_REQUIRED();

    /// @dev Reverts if implementation parameters are incorrect length
    error INVALID_IMPLEMENTATION_PARAMS();

    /// @dev Reverts if an implementation type is not valid
    error INVALID_IMPLEMENTATION_TYPE();

    ///                                                          ///
    ///                            STRUCTS                       ///
    ///                                                          ///

    /// @notice The founder parameters
    /// @param wallet The wallet address
    /// @param ownershipPct The percent ownership of the token
    /// @param vestExpiry The timestamp that vesting expires
    struct FounderParams {
        address wallet;
        uint256 ownershipPct;
        uint256 vestExpiry;
    }

    /// @notice DAO Version Information information struct
    struct DAOVersionInfo {
        string token;
        string metadata;
        string auction;
        string treasury;
        string governor;
    }

    /// @notice The ERC-721 token parameters
    /// @param impl The address of the implementation
    /// @param data The encoded implementation parameters
    struct ImplementationParams {
        address impl;
        bytes data;
    }

    ///                                                          ///
    ///                           FUNCTIONS                      ///
    ///                                                          ///

    /// @notice Deploys a DAO with custom token, auction, and governance settings
    /// @param founderParams The DAO founder(s)
    /// @param implAddresses The implementation addresses
    /// @param implData The encoded list of implementation data
    function deploy(
        FounderParams[] calldata founderParams,
        address[] calldata implAddresses,
        bytes[] calldata implData
    ) external returns (address token, address metadataRenderer, address auction, address treasury, address governor);

    /// @notice A DAO's remaining contract addresses from its token address
    /// @param token The ERC-721 token address
    function getAddresses(address token) external returns (address metadataRenderer, address auction, address treasury, address governor);

    /// @notice If an implementation is registered by the Builder DAO as an optional upgrade
    /// @param baseImpl The base implementation address
    /// @param upgradeImpl The upgrade implementation address
    function isRegisteredUpgrade(address baseImpl, address upgradeImpl) external view returns (bool);

    /// @notice Called by the Builder DAO to offer opt-in implementation upgrades for all other DAOs
    /// @param baseImpl The base implementation address
    /// @param upgradeImpl The upgrade implementation address
    function registerUpgrade(address baseImpl, address upgradeImpl) external;

    /// @notice Called by the Builder DAO to remove an upgrade
    /// @param baseImpl The base implementation address
    /// @param upgradeImpl The upgrade implementation address
    function removeUpgrade(address baseImpl, address upgradeImpl) external;
}
