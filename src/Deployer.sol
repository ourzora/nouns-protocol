// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {IToken} from "./token/Token.sol";
import {IMetadataRenderer} from "./token/metadata/IMetadataRenderer.sol";
import {IAuction} from "./auction/Auction.sol";
import {ITreasury} from "./governance/treasury/Treasury.sol";
import {IGovernor} from "./governance/governor/Governor.sol";
import {IDeployer} from "./IDeployer.sol";

/// @title Nounish DAO Deployer
/// @author Rohan Kulkarni
/// @notice This contract deploys Nounish DAOs with custom token, auction, and governance settings
contract Deployer is IDeployer {
    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    /// @notice The token implementation
    address public immutable tokenImpl;

    /// @notice The metadata renderer implementation
    address public immutable metadataImpl;

    /// @notice The auction house implementation
    address public immutable auctionImpl;

    /// @notice The treasury implementation
    address public immutable treasuryImpl;

    /// @notice The governor implementation
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
    ) {
        tokenImpl = _tokenImpl;
        metadataImpl = _metadataImpl;
        auctionImpl = _auctionImpl;
        treasuryImpl = _treasuryImpl;
        governorImpl = _governorImpl;
    }

    ///                                                          ///
    ///                             DEPLOY                       ///
    ///                                                          ///

    /// @notice Emitted when a Nounish DAO is deployed
    /// @param token The address of the token
    /// @param metadata The address of the metadata renderer
    /// @param auction The address of the auction
    /// @param treasury The address of the treasury
    /// @param governor The address of the governor
    event DAODeployed(address token, address metadata, address auction, address treasury, address governor);

    /// @notice Deploys a Nounish DAO
    /// @param _tokenParams The initial token config
    /// @param _auctionParams The initial auction config
    /// @param _govParams The initial governance config
    function deploy(
        TokenParams calldata _tokenParams,
        AuctionParams calldata _auctionParams,
        GovParams calldata _govParams
    )
        public
        returns (
            address token,
            address metadata,
            address auction,
            address treasury,
            address governor
        )
    {
        token = address(new ERC1967Proxy(tokenImpl, ""));
        metadata = address(new ERC1967Proxy(metadataImpl, ""));
        auction = address(new ERC1967Proxy(auctionImpl, ""));
        treasury = address(new ERC1967Proxy(treasuryImpl, ""));
        governor = address(new ERC1967Proxy(governorImpl, ""));

        IToken(token).initialize(
            _tokenParams.initStrings,
            metadata,
            _tokenParams.foundersDAO,
            _tokenParams.foundersMaxAllocation,
            _tokenParams.foundersAllocationFrequency,
            auction
        );

        IMetadataRenderer(metadata).initialize(_tokenParams.initStrings, token, _tokenParams.foundersDAO, treasury);

        IAuction(auction).initialize(token, _tokenParams.foundersDAO, treasury, _auctionParams.duration, _auctionParams.reservePrice);

        ITreasury(treasury).initialize(governor, _govParams.timelockDelay);

        IGovernor(governor).initialize(
            treasury,
            token,
            _govParams.votingDelay,
            _govParams.votingPeriod,
            _govParams.proposalThresholdBPS,
            _govParams.quorumVotesBPS
        );

        emit DAODeployed(token, metadata, auction, treasury, governor);
    }
}
