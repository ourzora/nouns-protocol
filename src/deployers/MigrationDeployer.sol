// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { IManager } from "../manager/IManager.sol";
import { IBaseToken } from "../token/interfaces/IBaseToken.sol";
import { IPropertyIPFSMetadataRenderer } from "../metadata/interfaces/IPropertyIPFSMetadataRenderer.sol";
import { MerkleReserveMinter } from "../minters/MerkleReserveMinter.sol";
import { TokenTypesV2 } from "../token/default/types/TokenTypesV2.sol";
import { Ownable } from "../lib/utils/Ownable.sol";
import { ICrossDomainMessenger } from "./interfaces/ICrossDomainMessenger.sol";

/// @title MigrationDeployer
/// @notice A deployer that allows a DAO to migrate from L1 to L2
/// @author @neokry
contract MigrationDeployer {
    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    /// @notice Deployer has been set
    event DeployerSet(address deployer);

    ///                                                          ///
    ///                            ERRORS                        ///
    ///                                                          ///

    /// @dev Caller is not cross domain messenger
    error NOT_CROSS_DOMAIN_MESSENGER();

    /// @dev DAO is already deployed
    error DAO_ALREADY_DEPLOYED();

    /// @dev No DAO has been deployed
    error NO_DAO_DEPLOYED();

    /// @dev Transfer failed
    error TRANSFER_FAILED();

    ///                                                          ///
    ///                            IMMUTABLES                    ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IManager public immutable manager;

    /// @notice The minter to deploy the DAO with
    MerkleReserveMinter public immutable merkleMinter;

    /// @notice The cross domain messenger for the chain
    ICrossDomainMessenger public immutable crossDomainMessenger;

    ///                                                          ///
    ///                            STORAGE                       ///
    ///                                                          ///

    /// @notice Mapping of L1 deployer => L2 deployed token
    mapping(address => address) public crossDomainDeployerToToken;

    ///                                                          ///
    ///                            MODIFIERS                     ///
    ///                                                          ///

    /// @notice Modifier to revert if sender is not cross domain messenger
    modifier onlyCrossDomainMessenger() {
        if (msg.sender != address(crossDomainMessenger)) revert NOT_CROSS_DOMAIN_MESSENGER();
        _;
    }

    ///                                                          ///
    ///                            CONSTRUCTOR                   ///
    ///                                                          ///

    constructor(
        IManager _manager,
        MerkleReserveMinter _merkleMinter,
        ICrossDomainMessenger _crossDomainMessenger
    ) {
        manager = _manager;
        merkleMinter = _merkleMinter;
        crossDomainMessenger = _crossDomainMessenger;
    }

    ///                                                          ///
    ///                            DEPLOYMENT                    ///
    ///                                                          ///

    /// @notice Deploys a DAO via cross domain message
    /// @dev The address of this deployer must be set as founder 0
    /// @param _founderParams The DAO founders
    /// @param _tokenParams The ERC-721 token settings
    /// @param _auctionParams The auction settings
    /// @param _govParams The governance settings
    /// @param _minterParams The minter settings
    function deploy(
        IManager.FounderParams[] calldata _founderParams,
        IManager.TokenParams calldata _tokenParams,
        IManager.AuctionParams calldata _auctionParams,
        IManager.GovParams calldata _govParams,
        MerkleReserveMinter.MerkleMinterSettings calldata _minterParams
    ) external onlyCrossDomainMessenger returns (address token) {
        if (_getTokenFromSender() != address(0)) {
            revert DAO_ALREADY_DEPLOYED();
        }

        // Deploy the DAO
        (address _token, , , , ) = manager.deploy(_founderParams, _tokenParams, _auctionParams, _govParams);

        // Setup minter settings to use the redeem minter
        TokenTypesV2.MinterParams[] memory minters = new TokenTypesV2.MinterParams[](1);
        minters[0] = TokenTypesV2.MinterParams({ minter: address(merkleMinter), allowed: true });

        // Add new minter
        IBaseToken(_token).updateMinters(minters);

        // Initilize minter with given params
        merkleMinter.setMintSettings(_token, _minterParams);

        // Set the deployer
        _setTokenDeployer(_token);

        return (_token);
    }

    ///@notice Adds metadata properties to the migrated DAO
    /// @param _names The names of the properties to add
    /// @param _items The items to add to each property
    /// @param _ipfsGroup The IPFS base URI and extension
    function addMetadataProperties(
        string[] calldata _names,
        IPropertyIPFSMetadataRenderer.ItemParam[] calldata _items,
        IPropertyIPFSMetadataRenderer.IPFSGroup calldata _ipfsGroup
    ) external onlyCrossDomainMessenger {
        (, address metadata, , , ) = _getDAOAddressesFromSender();
        IPropertyIPFSMetadataRenderer(metadata).addProperties(_names, _items, _ipfsGroup);
    }

    ///@notice Called once all metadata properties are added to set ownership of migrated DAO contracts to treasury
    function finalize() external onlyCrossDomainMessenger {
        (address token, , address auction, address treasury, ) = _getDAOAddressesFromSender();

        // Transfer ownership of token contract
        Ownable(token).transferOwnership(treasury);

        // Transfer ownership of auction contract
        Ownable(auction).transferOwnership(treasury);
    }

    ///@notice Resets the stored deployment if L1 DAO wants to redeploy
    function resetDeployment() external onlyCrossDomainMessenger {
        _resetTokenDeployer();
    }

    ///                                                          ///
    ///                            DEPOSIT                       ///
    ///                                                          ///

    ///@notice Helper method to deposit ether from L1 DAO treasury to L2 DAO treasury
    function depositToTreasury() external payable onlyCrossDomainMessenger {
        (, , , address treasury, ) = _getDAOAddressesFromSender();

        (bool success, ) = treasury.call{ value: msg.value }("");

        // Revert if transfer fails
        if (!success) {
            revert TRANSFER_FAILED();
        }
    }

    ///                                                          ///
    ///                            PRIVATE                       ///
    ///                                                          ///

    function _xMsgSender() private view returns (address) {
        return crossDomainMessenger.xDomainMessageSender();
    }

    function _setTokenDeployer(address token) private {
        crossDomainDeployerToToken[_xMsgSender()] = token;
    }

    function _resetTokenDeployer() private {
        delete crossDomainDeployerToToken[_xMsgSender()];
    }

    function _getTokenFromSender() private view returns (address) {
        return crossDomainDeployerToToken[_xMsgSender()];
    }

    function _getDAOAddressesFromSender()
        private
        returns (
            address token,
            address metadata,
            address auction,
            address treasury,
            address governor
        )
    {
        address _token = _getTokenFromSender();

        if (_token == address(0)) revert NO_DAO_DEPLOYED();

        (address _metadata, address _auction, address _treasury, address _governor) = manager.getAddresses(_token);
        return (_token, _metadata, _auction, _treasury, _governor);
    }
}
