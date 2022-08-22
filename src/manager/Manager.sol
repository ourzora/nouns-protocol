// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {UUPS} from "../lib/proxy/UUPS.sol";
import {Ownable} from "../lib/utils/Ownable.sol";
import {ERC1967Proxy} from "../lib/proxy/ERC1967Proxy.sol";

import {ManagerStorageV1} from "./storage/ManagerStorageV1.sol";
import {IManager} from "./IManager.sol";
import {IToken} from "../token/IToken.sol";
import {INounsMetadata} from "../token/metadata/INounsMetadata.sol";
import {IAuction} from "../auction/IAuction.sol";
import {ITimelock} from "../governance/timelock/ITimelock.sol";
import {IGovernor} from "../governance/governor/IGovernor.sol";

/// @title Manager
/// @author Rohan Kulkarni
/// @notice This contract manages DAO deployments and opt-in contract upgrades.
contract Manager is IManager, UUPS, Ownable, ManagerStorageV1 {
    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    /// @notice The address of the token implementation
    address public immutable tokenImpl;

    /// @notice The address of the metadata renderer implementation
    address public immutable metadataImpl;

    /// @notice The address of the auction house implementation
    address public immutable auctionImpl;

    /// @notice The address of the timelock implementation
    address public immutable timelockImpl;

    /// @notice The address of the governor implementation
    address public immutable governorImpl;

    /// @notice The hash of the metadata renderer bytecode to be deployed
    bytes32 private immutable metadataHash;

    /// @notice The hash of the auction bytecode to be deployed
    bytes32 private immutable auctionHash;

    /// @notice The hash of the timelock bytecode to be deployed
    bytes32 private immutable timelockHash;

    /// @notice The hash of the governor bytecode to be deployed
    bytes32 private immutable governorHash;

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    constructor(
        address _tokenImpl,
        address _metadataImpl,
        address _auctionImpl,
        address _timelockImpl,
        address _governorImpl
    ) payable initializer {
        tokenImpl = _tokenImpl;
        metadataImpl = _metadataImpl;
        auctionImpl = _auctionImpl;
        timelockImpl = _timelockImpl;
        governorImpl = _governorImpl;

        metadataHash = keccak256(abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(_metadataImpl, "")));
        auctionHash = keccak256(abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(_auctionImpl, "")));
        timelockHash = keccak256(abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(_timelockImpl, "")));
        governorHash = keccak256(abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(_governorImpl, "")));
    }

    ///                                                          ///
    ///                          INITIALIZER                     ///
    ///                                                          ///

    /// @notice Initializes ownership of the manager contract
    /// @param _owner The address of the owner to set
    function initialize(address _owner) external initializer {
        // Ensure an owner is specified
        if (_owner == address(0)) revert ADDRESS_ZERO();

        // Set the given address as the owner
        __Ownable_init(_owner);
    }

    ///                                                          ///
    ///                          DAO DEPLOY                      ///
    ///                                                          ///

    /// @notice Deploys a DAO with custom nounish settings
    /// @param _founderParams The founders allocation
    /// @param _tokenParams The token configuration
    /// @param _auctionParams The auction configuration
    /// @param _govParams The governance configuration
    function deploy(
        FounderParams[] calldata _founderParams,
        TokenParams calldata _tokenParams,
        AuctionParams calldata _auctionParams,
        GovParams calldata _govParams
    )
        external
        returns (
            address token,
            address metadata,
            address auction,
            address timelock,
            address governor
        )
    {
        // Used to store the founder responsible for adding token properties and kicking off the first auction
        address founder;

        // Ensure at least one founder address is provided
        if (((founder = _founderParams[0].wallet)) == address(0)) revert FOUNDER_REQUIRED();

        // Deploy an instance of the DAO's ERC-721 token
        token = address(new ERC1967Proxy(tokenImpl, ""));

        // Use the token address as a salt for the remaining deploys
        bytes32 salt = bytes32(uint256(uint160(token)));

        // Deploy the remaining contracts
        metadata = address(new ERC1967Proxy{salt: salt}(metadataImpl, ""));
        auction = address(new ERC1967Proxy{salt: salt}(auctionImpl, ""));
        timelock = address(new ERC1967Proxy{salt: salt}(timelockImpl, ""));
        governor = address(new ERC1967Proxy{salt: salt}(governorImpl, ""));

        // Initialize each with the given settings
        IToken(token).initialize(_founderParams, _tokenParams.initStrings, metadata, auction);
        INounsMetadata(metadata).initialize(_tokenParams.initStrings, token, founder, timelock);
        IAuction(auction).initialize(token, founder, timelock, _auctionParams.duration, _auctionParams.reservePrice);
        ITimelock(timelock).initialize(governor, _govParams.timelockDelay);
        IGovernor(governor).initialize(
            timelock,
            token,
            founder,
            _govParams.votingDelay,
            _govParams.votingPeriod,
            _govParams.proposalThresholdBPS,
            _govParams.quorumVotesBPS
        );

        emit DAODeployed(token, metadata, auction, timelock, governor);
    }

    ///                                                          ///
    ///                        DAO ADDRESSES                     ///
    ///                                                          ///

    /// @notice The addresses of a DAO's contracts from
    /// @param _token The ERC-721 token address
    function getAddresses(address _token)
        external
        view
        returns (
            address metadata,
            address auction,
            address timelock,
            address governor
        )
    {
        bytes32 salt = bytes32(uint256(uint160(_token)));

        metadata = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, metadataHash)))));
        auction = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, auctionHash)))));
        timelock = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, timelockHash)))));
        governor = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, governorHash)))));
    }

    ///                                                          ///
    ///                         DAO UPGRADES                     ///
    ///                                                          ///

    /// @notice Registers an implementation as a valid upgrade
    /// @param _baseImpl The address of the base implementation
    /// @param _upgradeImpl The address of the upgrade implementation to register
    function registerUpgrade(address _baseImpl, address _upgradeImpl) external onlyOwner {
        // Register the upgrade
        isUpgrade[_baseImpl][_upgradeImpl] = true;

        emit UpgradeRegistered(_baseImpl, _upgradeImpl);
    }

    /// @notice Unregisters an implementation
    /// @param _baseImpl The address of the base implementation
    /// @param _upgradeImpl The address of the upgrade implementation to unregister
    function unregisterUpgrade(address _baseImpl, address _upgradeImpl) external onlyOwner {
        // Remove the upgrade
        delete isUpgrade[_baseImpl][_upgradeImpl];

        emit UpgradeUnregistered(_baseImpl, _upgradeImpl);
    }

    /// @notice If an upgraded implementation has been registered for its original implementation
    /// @param _baseImpl The address of the original implementation
    /// @param _upgradeImpl The address of the upgrade implementation
    function isValidUpgrade(address _baseImpl, address _upgradeImpl) external view returns (bool) {
        return isUpgrade[_baseImpl][_upgradeImpl];
    }

    ///                                                          ///
    ///                        CONTRACT UPGRADE                  ///
    ///                                                          ///

    /// @notice Allows the default DAO implementations to be updated via Builder DAO governance
    /// @dev This function is called in `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The address of the new implementation
    function _authorizeUpgrade(address _newImpl) internal override onlyOwner {}
}
