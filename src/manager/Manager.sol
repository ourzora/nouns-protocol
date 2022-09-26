// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { UUPS } from "../lib/proxy/UUPS.sol";
import { Ownable } from "../lib/utils/Ownable.sol";
import { ERC1967Proxy } from "../lib/proxy/ERC1967Proxy.sol";

import { ManagerStorageV1 } from "./storage/ManagerStorageV1.sol";
import { IManager } from "./IManager.sol";
import { IToken } from "../token/IToken.sol";
import { IBaseMetadata } from "../token/metadata/interfaces/IBaseMetadata.sol";
import { IAuction } from "../auction/IAuction.sol";
import { ITreasury } from "../governance/treasury/ITreasury.sol";
import { IGovernor } from "../governance/governor/IGovernor.sol";

/// @title Manager
/// @author Rohan Kulkarni
/// @notice The DAO deployer and upgrade manager
contract Manager is IManager, UUPS, Ownable, ManagerStorageV1 {
    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    /// @notice The token implementation address
    address public immutable tokenImpl;

    /// @notice The metadata renderer implementation address
    address public immutable metadataImpl;

    /// @notice The auction house implementation address
    address public immutable auctionImpl;

    /// @notice The treasury implementation address
    address public immutable treasuryImpl;

    /// @notice The governor implementation address
    address public immutable governorImpl;

    /// @notice The metadata renderer bytecode hash
    bytes32 private immutable metadataHash;

    /// @notice The auction bytecode hash
    bytes32 private immutable auctionHash;

    /// @notice The treasury bytecode hash
    bytes32 private immutable treasuryHash;

    /// @notice The governor bytecode hash
    bytes32 private immutable governorHash;

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    constructor(
        address _tokenImpl,
        address _metadataImpl,
        address _auctionImpl,
        address _treasuryImpl,
        address _governorImpl
    ) payable initializer {
        tokenImpl = _tokenImpl;
        metadataImpl = _metadataImpl;
        auctionImpl = _auctionImpl;
        treasuryImpl = _treasuryImpl;
        governorImpl = _governorImpl;

        metadataHash = keccak256(abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(_metadataImpl, "")));
        auctionHash = keccak256(abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(_auctionImpl, "")));
        treasuryHash = keccak256(abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(_treasuryImpl, "")));
        governorHash = keccak256(abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(_governorImpl, "")));
    }

    ///                                                          ///
    ///                          INITIALIZER                     ///
    ///                                                          ///

    /// @notice Initializes ownership of the manager contract
    /// @param _owner The owner address to set (will be transferred to the Builder DAO once its deployed)
    function initialize(address _owner) external initializer {
        // Ensure an owner is specified
        if (_owner == address(0)) revert ADDRESS_ZERO();

        // Set the contract owner
        __Ownable_init(_owner);
    }

    ///                                                          ///
    ///                           DAO DEPLOY                     ///
    ///                                                          ///

    /// @notice Deploys a DAO with custom token, auction, and governance settings
    /// @param _founderParams The DAO founders
    /// @param _tokenParams The ERC-721 token settings
    /// @param _auctionParams The auction settings
    /// @param _govParams The governance settings
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
            address treasury,
            address governor
        )
    {
        // Used to store the address of the first (or only) founder
        // This founder is responsible for adding token artwork and launching the first auction -- they're also free to transfer this responsiblity
        address founder;

        // Ensure at least one founder is provided
        if ((founder = _founderParams[0].wallet) == address(0)) revert FOUNDER_REQUIRED();

        // Deploy the DAO's ERC-721 governance token
        token = address(new ERC1967Proxy(tokenImpl, ""));

        // Use the token address to precompute the DAO's remaining addresses
        bytes32 salt = bytes32(uint256(uint160(token)) << 96);

        // Deploy the remaining DAO contracts
        metadata = address(new ERC1967Proxy{ salt: salt }(metadataImpl, ""));
        auction = address(new ERC1967Proxy{ salt: salt }(auctionImpl, ""));
        treasury = address(new ERC1967Proxy{ salt: salt }(treasuryImpl, ""));
        governor = address(new ERC1967Proxy{ salt: salt }(governorImpl, ""));

        // Initialize each instance with the provided settings
        IToken(token).initialize(_founderParams, _tokenParams.initStrings, metadata, auction);
        IBaseMetadata(metadata).initialize(_tokenParams.initStrings, token, founder, treasury);
        IAuction(auction).initialize(token, founder, treasury, _auctionParams.duration, _auctionParams.reservePrice);
        ITreasury(treasury).initialize(governor, _govParams.timelockDelay);
        IGovernor(governor).initialize(
            treasury,
            token,
            founder,
            _govParams.votingDelay,
            _govParams.votingPeriod,
            _govParams.proposalThresholdBps,
            _govParams.quorumThresholdBps
        );

        emit DAODeployed(token, metadata, auction, treasury, governor);
    }

    ///                                                          ///
    ///                         DAO ADDRESSES                    ///
    ///                                                          ///

    /// @notice A DAO's contract addresses from its token
    /// @param _token The ERC-721 token address
    function getAddresses(address _token)
        external
        view
        returns (
            address metadata,
            address auction,
            address treasury,
            address governor
        )
    {
        bytes32 salt = bytes32(uint256(uint160(_token)) << 96);

        metadata = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, metadataHash)))));
        auction = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, auctionHash)))));
        treasury = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, treasuryHash)))));
        governor = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, governorHash)))));
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

    ///                                                          ///
    ///                         MANAGER UPGRADE                  ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract
    /// @dev This function is called in `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The new implementation address
    function _authorizeUpgrade(address _newImpl) internal override onlyOwner {}
}
