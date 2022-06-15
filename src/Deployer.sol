// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {Token} from "./token/Token.sol";
import {IToken} from "./token/IToken.sol";
import {IAuctionHouse, AuctionHouse} from "./auction/AuctionHouse.sol";
import {ITreasury, Treasury} from "./governance/treasury/Treasury.sol";
import {IGovernor, Governor} from "./governance/governor/Governor.sol";
import {Proxy} from "./upgrades/proxy/Proxy.sol";

import {IUpgradeManager} from "./upgrades/IUpgradeManager.sol";
import {IDeployer} from "./IDeployer.sol";

/// @title Nounish DAO Deployer
/// @author Rohan Kulkarni
/// @notice This contract deploys Nounish DAOs from generalized token, auction, and governance parameters
contract Deployer {
    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IUpgradeManager private immutable UpgradeManager;

    /// @notice The token v1 implementation
    address public immutable tokenImpl;

    /// @notice The auction house v1 implementation
    address public immutable auctionImpl;

    /// @notice The governor v1 implementation
    address public immutable governorImpl;

    /// @notice The treasury v1 implementation
    address public immutable treasuryImpl;

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    constructor(
        address _upgradeManager,
        address _tokenImpl,
        address _auctionImpl,
        address _governorImpl,
        address _treasuryImpl
    ) {
        UpgradeManager = IUpgradeManager(_upgradeManager);
        tokenImpl = _tokenImpl;
        auctionImpl = _auctionImpl;
        governorImpl = _governorImpl;
        treasuryImpl = _treasuryImpl;
    }

    ///                                                          ///
    ///                             DEPLOY                       ///
    ///                                                          ///

    /// @notice Emitted when a DAO has been deployed an ownership has been transferred to the treasury
    /// @param token The address of the token
    /// @param auction The address of the auction
    /// @param governor The address of the governor
    /// @param treasury The address of the treasury
    event DAODeployed(address token, address auction, address governor, address treasury);

    /// @notice Deploys a Nounish DAO from the given
    /// @param _tokenParams The specified token parameters
    /// @param _auctionParams The specified auction parameters
    function deploy(IDeployer.TokenParams calldata _tokenParams, IDeployer.AuctionParams calldata _auctionParams) public {
        // Deploy proxy instances of all implementations
        address token = address(new Proxy(tokenImpl, ""));
        address auction = address(new Proxy(auctionImpl, ""));
        address governor = address(new Proxy(governorImpl, ""));
        address treasury = address(new Proxy(treasuryImpl, ""));

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
        IAuctionHouse(auction).initialize(
            token,
            treasury,
            _auctionParams.timeBuffer,
            _auctionParams.reservePrice,
            _auctionParams.minBidIncrementPercentage,
            _auctionParams.duration
        );

        // Initialize the treasury
        ITreasury(treasury).initialize(governor);

        // Initialize the governor
        IGovernor(governor).initialize(treasury, token, _tokenParams.foundersDAO);

        emit DAODeployed(token, auction, governor, treasury);
    }
}
