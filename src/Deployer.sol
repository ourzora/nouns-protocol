// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {IToken} from "./token/Token.sol";
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

    /// @notice The default token implementation
    address public immutable tokenImpl;

    /// @notice The default auction house implementation
    address public immutable auctionImpl;

    /// @notice The default treasury implementation
    address public immutable treasuryImpl;

    /// @notice The default governor implementation
    address public immutable governorImpl;

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    constructor(
        address _tokenImpl,
        address _auctionImpl,
        address _treasuryImpl,
        address _governorImpl
    ) {
        tokenImpl = _tokenImpl;
        auctionImpl = _auctionImpl;
        treasuryImpl = _treasuryImpl;
        governorImpl = _governorImpl;
    }

    ///                                                          ///
    ///                             DEPLOY                       ///
    ///                                                          ///

    /// @notice Emitted when a DAO has been deployed an ownership has been transferred to the treasury
    /// @param token The address of the token
    /// @param auction The address of the auction
    /// @param treasury The address of the treasury
    /// @param governor The address of the governor
    event DAODeployed(address token, address auction, address treasury, address governor);

    /// @notice Deploys a Nounish DAO with the provided
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
            address auction,
            address treasury,
            address governor
        )
    {
        // Deploy proxy instances of all implementations
        token = address(new ERC1967Proxy(tokenImpl, ""));
        auction = address(new ERC1967Proxy(auctionImpl, ""));
        treasury = address(new ERC1967Proxy(treasuryImpl, ""));
        governor = address(new ERC1967Proxy(governorImpl, ""));

        // Initialize the token
        IToken(token).initialize(
            _tokenParams.name,
            _tokenParams.symbol,
            _tokenParams.metadataRenderer,
            _tokenParams.foundersDAO,
            _tokenParams.foundersMaxAllocation,
            _tokenParams.foundersAllocationFrequency,
            treasury,
            auction
        );

        // Initialize the auction house
        IAuction(auction).initialize(
            token,
            _tokenParams.foundersDAO,
            _auctionParams.timeBuffer,
            _auctionParams.reservePrice,
            _auctionParams.minBidIncrementPercentage,
            _auctionParams.duration
        );

        // Initialize the treasury
        ITreasury(treasury).initialize(governor, _govParams.timelockDelay);

        // Initialize the governor
        IGovernor(governor).initialize(
            treasury,
            token,
            _govParams.votingDelay,
            _govParams.votingPeriod,
            _govParams.proposalThresholdBPS,
            _govParams.quorumVotesBPS
        );

        emit DAODeployed(token, auction, treasury, governor);
    }
}
