// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { UUPS } from "../lib/proxy/UUPS.sol";
import { Ownable } from "../lib/utils/Ownable.sol";
import { ERC1967Proxy } from "../lib/proxy/ERC1967Proxy.sol";

import { ManagerStorageV1 } from "./storage/ManagerStorageV1.sol";
import { ManagerStorageV2 } from "./storage/ManagerStorageV2.sol";
import { IManager } from "./IManager.sol";
import { IToken } from "../token/IToken.sol";
import { IBaseMetadata } from "../token/metadata/interfaces/IBaseMetadata.sol";
import { IAuction } from "../auction/IAuction.sol";
import { ITreasury } from "../governance/treasury/ITreasury.sol";
import { IGovernor } from "../governance/governor/IGovernor.sol";

import { VersionedContract } from "../VersionedContract.sol";
import { IVersionedContract } from "../lib/interfaces/IVersionedContract.sol";

/// @title Manager
/// @author Neokry & Rohan Kulkarni
/// @custom:repo github.com/ourzora/nouns-protocol
/// @notice The DAO deployer and upgrade manager
contract Manager is IManager, VersionedContract, UUPS, Ownable, ManagerStorageV1, ManagerStorageV2 {
    ///                                                          ///
    ///                          CONSTANTS                       ///
    ///                                                          ///

    /// @notice The count of implementation types
    uint8 public constant IMPLEMENTATION_TYPE_COUNT = 5;

    // Public constants for implementation types.
    // Allows for adding new types later easily compared to a enum.
    uint8 public constant IMPLEMENTATION_TYPE_TOKEN = 0;
    uint8 public constant IMPLEMENTATION_TYPE_METADATA = 1;
    uint8 public constant IMPLEMENTATION_TYPE_AUCTION = 2;
    uint8 public constant IMPLEMENTATION_TYPE_TREASURY = 3;
    uint8 public constant IMPLEMENTATION_TYPE_GOVERNOR = 4;

    ///                                                          ///
    ///                          INITIALIZER                     ///
    ///                                                          ///

    /// @notice Initializes ownership of the manager contract
    /// @param _newOwner The owner address to set (will be transferred to the Builder DAO once its deployed)
    function initialize(address _newOwner) external initializer {
        // Ensure an owner is specified
        if (_newOwner == address(0)) revert ADDRESS_ZERO();

        // Set the contract owner
        __Ownable_init(_newOwner);
    }

    ///                                                          ///
    ///                           DAO DEPLOY                     ///
    ///                                                          ///

    /// @notice Deploys a DAO with custom token, auction, and governance settings
    /// @param _founderParams The DAO founders
    /// @param _implAddresses The implementation addresses
    /// @param _implData The encoded list of implementation data
    function deploy(
        FounderParams[] calldata _founderParams,
        address[] calldata _implAddresses,
        bytes[] calldata _implData
    ) external returns (address token, address metadata, address auction, address treasury, address governor) {
        // Used to store the address of the first (or only) founder
        // This founder is responsible for adding token artwork and launching the first auction -- they're also free to transfer this responsiblity
        address founder;

        // Ensure at least one founder is provided
        if ((founder = _founderParams[0].wallet) == address(0)) revert FOUNDER_REQUIRED();

        uint256 implAddressesLength = _implAddresses.length;

        // Ensure implementation parameters are correct length
        if (implAddressesLength != IMPLEMENTATION_TYPE_COUNT || _implData.length != IMPLEMENTATION_TYPE_COUNT) revert INVALID_IMPLEMENTATION_PARAMS();

        // Ensure all implementations are registered
        unchecked {
            for (uint256 i; i < implAddressesLength; ++i) {
                if (!isImplementation[uint8(i)][_implAddresses[i]]) revert IMPLEMENTATION_NOT_REGISTERED();
            }
        }

        // Deploy the DAO's ERC-721 governance token
        token = address(new ERC1967Proxy(_implAddresses[IMPLEMENTATION_TYPE_TOKEN], ""));

        // Use the token address to precompute the DAO's remaining addresses
        bytes32 salt = bytes32(uint256(uint160(token)) << 96);

        // Deploy the remaining DAO contracts
        metadata = address(new ERC1967Proxy{ salt: salt }(_implAddresses[IMPLEMENTATION_TYPE_METADATA], ""));
        auction = address(new ERC1967Proxy{ salt: salt }(_implAddresses[IMPLEMENTATION_TYPE_AUCTION], ""));
        treasury = address(new ERC1967Proxy{ salt: salt }(_implAddresses[IMPLEMENTATION_TYPE_TREASURY], ""));
        governor = address(new ERC1967Proxy{ salt: salt }(_implAddresses[IMPLEMENTATION_TYPE_GOVERNOR], ""));

        daoAddressesByToken[token] = DAOAddresses({ metadata: metadata, auction: auction, treasury: treasury, governor: governor });

        // Initialize each instance with the provided settings
        IToken(token).initialize({
            founders: _founderParams,
            metadataRenderer: metadata,
            auction: auction,
            initialOwner: founder,
            data: _implData[IMPLEMENTATION_TYPE_TOKEN]
        });
        IBaseMetadata(metadata).initialize({ token: token, data: _implData[IMPLEMENTATION_TYPE_METADATA] });
        IAuction(auction).initialize({ token: token, founder: founder, treasury: treasury, data: _implData[IMPLEMENTATION_TYPE_AUCTION] });
        ITreasury(treasury).initialize({ governor: governor, data: _implData[IMPLEMENTATION_TYPE_TREASURY] });
        IGovernor(governor).initialize({ treasury: treasury, token: token, data: _implData[IMPLEMENTATION_TYPE_GOVERNOR] });

        emit DAODeployed({ token: token, metadata: metadata, auction: auction, treasury: treasury, governor: governor });
    }

    ///                                                          ///
    ///                         DAO ADDRESSES                    ///
    ///                                                          ///

    /// @notice A DAO's contract addresses from its token
    /// @param _token The ERC-721 token address
    /// @return metadata Metadata deployed address
    /// @return auction Auction deployed address
    /// @return treasury Treasury deployed address
    /// @return governor Governor deployed address
    function getAddresses(address _token) public view returns (address metadata, address auction, address treasury, address governor) {
        DAOAddresses storage addresses = daoAddressesByToken[_token];

        metadata = addresses.metadata;
        auction = addresses.auction;
        treasury = addresses.treasury;
        governor = addresses.governor;
    }

    ///                                                          ///
    ///                          DAO Implementations             ///
    ///                                                          ///

    /// @notice If an implementation is registered by the Builder DAO as an option for deployment
    /// @param _implType The implementation type
    /// @param _implAddress The implementation address
    function isRegisteredImplementation(uint8 _implType, address _implAddress) external view returns (bool) {
        return isImplementation[_implType][_implAddress];
    }

    /// @notice Called by the Builder DAO to offer implementation choices when creating DAOs
    /// @param _implType The implementation type
    /// @param _implAddress The implementation address
    function registerImplementation(uint8 _implType, address _implAddress) external onlyOwner {
        if (_isInvalidImplementationType(_implType)) revert INVALID_IMPLEMENTATION_TYPE();
        isImplementation[_implType][_implAddress] = true;

        emit ImplementationRegistered(_implType, _implAddress);
    }

    /// @notice Called by the Builder DAO to remove an implementation option
    /// @param _implType The implementation type
    /// @param _implAddress The implementation address
    function removeImplementation(uint8 _implType, address _implAddress) external onlyOwner {
        if (_isInvalidImplementationType(_implType)) revert INVALID_IMPLEMENTATION_TYPE();
        delete isImplementation[_implType][_implAddress];

        emit ImplementationRemoved(_implType, _implAddress);
    }

    ///                                                          ///
    ///                          DAO UPGRADES                    ///
    ///                                                          ///

    /// @notice If an implementation is registered by the Builder DAO as an optional upgrade
    /// @param _baseImpl The base implementation address
    /// @param _upgradeImpl The upgrade implementation address
    function isRegisteredUpgrade(address _baseImpl, address _upgradeImpl) external view returns (bool) {
        return isUpgrade[_baseImpl][_upgradeImpl];
    }

    /// @notice Called by the Builder DAO to offer implementation upgrades for created DAOs
    /// @param _baseImpl The base implementation address
    /// @param _upgradeImpl The upgrade implementation address
    function registerUpgrade(address _baseImpl, address _upgradeImpl) external onlyOwner {
        isUpgrade[_baseImpl][_upgradeImpl] = true;

        emit UpgradeRegistered(_baseImpl, _upgradeImpl);
    }

    /// @notice Called by the Builder DAO to remove an upgrade
    /// @param _baseImpl The base implementation address
    /// @param _upgradeImpl The upgrade implementation address
    function removeUpgrade(address _baseImpl, address _upgradeImpl) external onlyOwner {
        delete isUpgrade[_baseImpl][_upgradeImpl];

        emit UpgradeRemoved(_baseImpl, _upgradeImpl);
    }

    /// @notice Check if an implementation type is invalid
    /// @param _implType The implementation type to check
    function _isInvalidImplementationType(uint8 _implType) internal pure returns (bool) {
        return _implType > IMPLEMENTATION_TYPE_COUNT;
    }

    /// @notice Safely get the contract version of a target contract.
    /// @dev Assume `target` is a contract
    /// @return Contract version if found, empty string if not.
    function _safeGetVersion(address target) internal pure returns (string memory) {
        try IVersionedContract(target).contractVersion() returns (string memory version) {
            return version;
        } catch {
            return "";
        }
    }

    function getDAOVersions(address token) external view returns (DAOVersionInfo memory) {
        (address metadata, address auction, address treasury, address governor) = getAddresses(token);
        return
            DAOVersionInfo({
                token: _safeGetVersion(token),
                metadata: _safeGetVersion(metadata),
                auction: _safeGetVersion(auction),
                treasury: _safeGetVersion(treasury),
                governor: _safeGetVersion(governor)
            });
    }

    ///                                                          ///
    ///                         MANAGER UPGRADE                  ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract
    /// @dev This function is called in `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The new implementation address
    function _authorizeUpgrade(address _newImpl) internal override onlyOwner {}
}
