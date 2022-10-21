// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

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
    }

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

        daoAddressesByToken[token] = DAOAddresses({ metadata: metadata, auction: auction, treasury: treasury, governor: governor });

        // Initialize each instance with the provided settings
        IToken(token).initialize({
            founders: _founderParams,
            initStrings: _tokenParams.initStrings,
            metadataRenderer: metadata,
            auction: auction,
            initialOwner: founder
        });
        IBaseMetadata(metadata).initialize({ initStrings: _tokenParams.initStrings, token: token });
        IAuction(auction).initialize({
            token: token,
            founder: founder,
            treasury: treasury,
            duration: _auctionParams.duration,
            reservePrice: _auctionParams.reservePrice
        });
        ITreasury(treasury).initialize({ governor: governor, timelockDelay: _govParams.timelockDelay });
        IGovernor(governor).initialize({
            treasury: treasury,
            token: token,
            vetoer: _govParams.vetoer,
            votingDelay: _govParams.votingDelay,
            votingPeriod: _govParams.votingPeriod,
            proposalThresholdBps: _govParams.proposalThresholdBps,
            quorumThresholdBps: _govParams.quorumThresholdBps
        });

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
        DAOAddresses storage addresses = daoAddressesByToken[_token];

        metadata = addresses.metadata;
        auction = addresses.auction;
        treasury = addresses.treasury;
        governor = addresses.governor;
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
