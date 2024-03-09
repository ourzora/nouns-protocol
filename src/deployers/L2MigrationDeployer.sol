// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { IManager } from "../manager/IManager.sol";
import { IToken } from "../token/IToken.sol";
import { IGovernor } from "../governance/governor/IGovernor.sol";
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
    ///                            STRUCTS                       ///
    ///                                                          ///

    /// @notice The migration configuration for a deployment
    /// @param tokenAddress The address of the deployed token
    /// @param minimumMetadataCalls The minimum number of metadata calls expected to be made
    /// @param executedMetadataCalls The number of metadata calls that have been executed
    struct MigrationConfig {
        address tokenAddress;
        uint256 minimumMetadataCalls;
        uint256 executedMetadataCalls;
    }

    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    /// @notice Deployer has been set
    event DeployerSet(address indexed token, address indexed deployer);

    /// @notice Ownership has been renounced
    event OwnershipRenounced(address indexed token, address indexed deployer);

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

    /// @dev Metadata calls not executed
    error METADATA_CALLS_NOT_EXECUTED();

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

    /// @notice Mapping of L1 deployer => L2 migration config
    mapping(address => MigrationConfig) public crossDomainDeployerToMigration;

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
    /// @param _delayedGovernanceAmount The amount of time to delay governance by
    function deploy(
        IManager.FounderParams[] calldata _founderParams,
        IManager.TokenParams calldata _tokenParams,
        IManager.AuctionParams calldata _auctionParams,
        IManager.GovParams calldata _govParams,
        MerkleReserveMinter.MerkleMinterSettings calldata _minterParams,
        uint256 _delayedGovernanceAmount,
        uint256 _minimumMetadataCalls
    ) external returns (address token) {
        if (_getTokenFromSender() != address(0)) {
            revert DAO_ALREADY_DEPLOYED();
        }

        // Deploy the DAO
        (address _token, , , , address _governor) = IManager(manager).deploy(_founderParams, _tokenParams, _auctionParams, _govParams);

        // Set the governance expiration
        IGovernor(_governor).updateDelayedGovernanceExpirationTimestamp(block.timestamp + _delayedGovernanceAmount);

        // Setup minter settings to use the redeem minter
        TokenTypesV2.MinterParams[] memory minters = new TokenTypesV2.MinterParams[](1);
        minters[0] = TokenTypesV2.MinterParams({ minter: address(merkleMinter), allowed: true });

        // Add new minter
        IToken(_token).updateMinters(minters);

        // Initilize minter with given params
        MerkleReserveMinter(merkleMinter).setMintSettings(_token, _minterParams);

        // Set the migration config
        address deployer = _setMigrationConfig(_token, _minimumMetadataCalls);

        // Emit deployer set event
        emit DeployerSet(_token, deployer);

        return (_token);
    }

    ///@notice Resets the stored deployment if L1 DAO wants to redeploy
    function resetDeployment() external {
        _resetMigrationConfig();
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

        // Increment the number of metadata calls
        crossDomainDeployerToMigration[_xMsgSender()].executedMetadataCalls++;

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

        MigrationConfig storage migration = crossDomainDeployerToMigration[_xMsgSender()];

        // Revert if the minimum amount of metadata calls have not been executed
        if (migration.executedMetadataCalls < migration.minimumMetadataCalls) {
            revert METADATA_CALLS_NOT_EXECUTED();
        }

        // Transfer ownership of token contract
        Ownable(token).transferOwnership(treasury);

        // Transfer ownership of auction contract
        Ownable(auction).transferOwnership(treasury);

        address deployer = _xMsgSender();
        emit OwnershipRenounced(token, deployer);
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

    function _setMigrationConfig(address token, uint256 minimumMetadataCalls) private returns (address deployer) {
        deployer = _xMsgSender();

        crossDomainDeployerToMigration[deployer].tokenAddress = token;
        crossDomainDeployerToMigration[deployer].minimumMetadataCalls = minimumMetadataCalls;
        crossDomainDeployerToMigration[deployer].executedMetadataCalls = 0;
    }

    function _resetMigrationConfig() private {
        // Reset the deployer state so the xDomain caller can redeploy
        delete crossDomainDeployerToMigration[_xMsgSender()];
    }

    function _getTokenFromSender() private view returns (address) {
        // Return the token address if it has been deployed by the xDomain caller
        return crossDomainDeployerToMigration[_xMsgSender()].tokenAddress;
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
