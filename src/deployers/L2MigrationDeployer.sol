// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { IManager } from "../manager/IManager.sol";
import { IToken } from "../token/IToken.sol";
import { IPropertyIPFSMetadataRenderer } from "../token/metadata/interfaces/IPropertyIPFSMetadataRenderer.sol";
import { MerkleReserveMinter } from "../minters/MerkleReserveMinter.sol";
import { TokenTypesV2 } from "../token/types/TokenTypesV2.sol";
import { Ownable } from "../lib/utils/Ownable.sol";
import { ICrossDomainMessenger } from "./interfaces/ICrossDomainMessenger.sol";
import { OPAddressAliasHelper } from "../lib/utils/OPAddressAliasHelper.sol";

/// @title L2MigrationDeployer
/// @notice A deployer that allows a caller on L1 to deploy and seed a DAO on an OP Stack L2
/// @dev This contract is designed to be called from the OPStack L1CrossDomainMessenger or OptimismPortal
/// @author @neokry
contract L2MigrationDeployer {
    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    /// @notice Deployer has been set
    event DeployerSet(address indexed token, address indexed deployer);

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

    /// @dev Metadata call failed
    error METADATA_CALL_FAILED();

    ///                                                          ///
    ///                            IMMUTABLES                    ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    address public immutable manager;

    /// @notice The minter to deploy the DAO with
    address public immutable merkleMinter;

    /// @notice The cross domain messenger for the chain
    address public immutable crossDomainMessenger;

    ///                                                          ///
    ///                            STORAGE                       ///
    ///                                                          ///

    /// @notice Mapping of L1 deployer => L2 deployed token
    mapping(address => address) public crossDomainDeployerToToken;

    ///                                                          ///
    ///                            CONSTRUCTOR                   ///
    ///                                                          ///

    constructor(
        address _manager,
        address _merkleMinter,
        address _crossDomainMessenger
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
    ) external returns (address token) {
        if (_getTokenFromSender() != address(0)) {
            revert DAO_ALREADY_DEPLOYED();
        }

        // Deploy the DAO
        (address _token, , , , ) = IManager(manager).deploy(_founderParams, _tokenParams, _auctionParams, _govParams);

        // Setup minter settings to use the redeem minter
        TokenTypesV2.MinterParams[] memory minters = new TokenTypesV2.MinterParams[](1);
        minters[0] = TokenTypesV2.MinterParams({ minter: address(merkleMinter), allowed: true });

        // Add new minter
        IToken(_token).updateMinters(minters);

        // Initilize minter with given params
        MerkleReserveMinter(merkleMinter).setMintSettings(_token, _minterParams);

        // Set the deployer
        address deployer = _setTokenDeployer(_token);

        // Emit deployer set event
        emit DeployerSet(_token, deployer);

        return (_token);
    }

    ///@notice Resets the stored deployment if L1 DAO wants to redeploy
    function resetDeployment() external {
        _resetTokenDeployer();
    }

    ///                                                          ///
    ///                            HELPER FUNCTIONS              ///
    ///                                                          ///

    /// @notice Helper method to get the address alias for simulation purposes
    /// @param l1Address The L1 address to apply the alias to
    function applyL1ToL2Alias(address l1Address) external pure returns (address) {
        return OPAddressAliasHelper.applyL1ToL2Alias(l1Address);
    }

    ///@notice Helper method to pass a call along to the deployed metadata renderer
    /// @param _data The names of the properties to add
    function callMetadataRenderer(bytes memory _data) external {
        (, address metadata, , , ) = _getDAOAddressesFromSender();

        // Call the metadata renderer
        (bool success, ) = metadata.call(_data);

        // Revert if metadata call fails
        if (!success) {
            revert METADATA_CALL_FAILED();
        }
    }

    ///@notice Helper method to deposit ether from L1 DAO treasury to L2 DAO treasury
    function depositToTreasury() external payable {
        (, , , address treasury, ) = _getDAOAddressesFromSender();

        // Transfer ether to treasury
        (bool success, ) = treasury.call{ value: msg.value }("");

        // Revert if transfer fails
        if (!success) {
            revert TRANSFER_FAILED();
        }
    }

    ///@notice Transfers ownership of migrated DAO contracts to treasury
    function renounceOwnership() external {
        (address token, , address auction, address treasury, ) = _getDAOAddressesFromSender();

        // Transfer ownership of token contract
        Ownable(token).transferOwnership(treasury);

        // Transfer ownership of auction contract
        Ownable(auction).transferOwnership(treasury);
    }

    ///                                                          ///
    ///                            PRIVATE                       ///
    ///                                                          ///

    function _xMsgSender() private view returns (address) {
        // Return the xDomain message sender
        return
            msg.sender == crossDomainMessenger
                ? ICrossDomainMessenger(crossDomainMessenger).xDomainMessageSender()
                : OPAddressAliasHelper.undoL1ToL2Alias(msg.sender);
    }

    function _setTokenDeployer(address token) private returns (address deployer) {
        deployer = _xMsgSender();

        // Set the deployer state so the xDomain caller can easily access in future calls
        // Also prevents accidental re-deployment
        crossDomainDeployerToToken[deployer] = token;
    }

    function _resetTokenDeployer() private {
        // Reset the deployer state so the xDomain caller can redeploy
        delete crossDomainDeployerToToken[_xMsgSender()];
    }

    function _getTokenFromSender() private view returns (address) {
        // Return the token address if it has been deployed by the xDomain caller
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

        // Revert if no token has been deployed
        if (_token == address(0)) revert NO_DAO_DEPLOYED();

        // Get the DAO addresses
        (address _metadata, address _auction, address _treasury, address _governor) = IManager(manager).getAddresses(_token);
        return (_token, _metadata, _auction, _treasury, _governor);
    }
}
