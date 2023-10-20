// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { IManager } from "../manager/IManager.sol";
import { IBaseToken } from "../token/interfaces/IBaseToken.sol";
import { IPropertyIPFSMetadataRenderer } from "../metadata/interfaces/IPropertyIPFSMetadataRenderer.sol";
import { ERC721RedeemMinter } from "../minters/ERC721RedeemMinter.sol";
import { TokenTypesV2 } from "../token/default/types/TokenTypesV2.sol";
import { Ownable } from "../lib/utils/Ownable.sol";

/// @title CollectionPlusDeployer
/// @notice A deployer that allows a user to deploy a Collection Plus style DAO in one transaction
/// @author @neokry
contract CollectionPlusDeployer {
    ///                                                          ///
    ///                            IMMUTABLES                    ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IManager public immutable manager;

    /// @notice The minter to deploy the DAO with
    ERC721RedeemMinter public immutable redeemMinter;

    ///                                                          ///
    ///                            STRUCTS                       ///
    ///                                                          ///

    /// @notice Adds properties and/or items to be pseudo-randomly chosen from during token minting
    /// @param names The names of the properties to add
    /// @param items The items to add to each property
    /// @param ipfsGroup The IPFS base URI and extension
    struct MetadataParams {
        string[] names;
        IPropertyIPFSMetadataRenderer.ItemParam[] items;
        IPropertyIPFSMetadataRenderer.IPFSGroup ipfsGroup;
    }

    ///                                                          ///
    ///                            CONSTRUCTOR                   ///
    ///                                                          ///

    constructor(IManager _manager, ERC721RedeemMinter _redeemMinter) {
        manager = _manager;
        redeemMinter = _redeemMinter;
    }

    ///                                                          ///
    ///                            DEPLOYMENT                    ///
    ///                                                          ///

    /// @notice Deploys a DAO with mirror and token redeeming enabled
    /// @dev The address of this deployer must be set as founder 0
    /// @param _founderParams The DAO founders
    /// @param _tokenParams The ERC-721 token settings
    /// @param _auctionParams The auction settings
    /// @param _govParams The governance settings
    /// @param _metadataParams The metadata settings
    /// @param _minterParams The minter settings
    function deploy(
        IManager.FounderParams[] calldata _founderParams,
        IManager.MirrorTokenParams calldata _tokenParams,
        IManager.AuctionParams calldata _auctionParams,
        IManager.GovParams calldata _govParams,
        MetadataParams calldata _metadataParams,
        ERC721RedeemMinter.RedeemSettings calldata _minterParams
    ) external returns (address) {
        // Deploy the DAO with token mirroring enabled
        (address token, address metadata, address auction, address treasury, ) = manager.deployWithMirror(
            _founderParams,
            _tokenParams,
            _auctionParams,
            _govParams
        );

        // Setup minter settings to use the redeem minter
        TokenTypesV2.MinterParams[] memory minters = new TokenTypesV2.MinterParams[](1);
        minters[0] = TokenTypesV2.MinterParams({ minter: address(redeemMinter), allowed: true });

        // Add new minter
        IBaseToken(token).updateMinters(minters);

        // Initilize minter with given params
        redeemMinter.setMintSettings(token, _minterParams);

        // Initilize metadata renderer with given params
        IPropertyIPFSMetadataRenderer(metadata).addProperties(_metadataParams.names, _metadataParams.items, _metadataParams.ipfsGroup);

        // Transfer ownership of token contract
        Ownable(token).transferOwnership(treasury);

        // Transfer ownership of auction contract
        Ownable(auction).transferOwnership(treasury);

        return token;
    }
}
