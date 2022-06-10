// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {IToken, Token} from "./token/Token.sol";
import {IAuctionHouse, AuctionHouse} from "./auction/AuctionHouse.sol";
import {ITreasury, Treasury} from "./governance/treasury/Treasury.sol";
import {IGovernor, Governor} from "./governance/governor/Governor.sol";
import {Proxy} from "./upgrades/proxy/Proxy.sol";

import {IUpgradeManager} from "./upgrades/IUpgradeManager.sol";
import {IDeployer} from "./IDeployer.sol";

contract Deployer {
    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    IUpgradeManager private immutable UpgradeManager;

    address public immutable tokenImpl;
    address public immutable auctionImpl;
    address public immutable governorImpl;
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

    function deploy(IDeployer.TokenParams calldata _tokenParams, IDeployer.AuctionParams calldata _auctionParams) public {
        address governor = address(new Proxy(governorImpl, ""));
        address treasury = address(new Proxy(treasuryImpl, ""));
        address token = address(new Proxy(tokenImpl, ""));
        address auction = address(new Proxy(auctionImpl, ""));

        IToken(token).initialize(
            _tokenParams.name,
            _tokenParams.symbol,
            _tokenParams.foundersDAO,
            _tokenParams.foundersMaxAllocation,
            _tokenParams.foundersAllocationFrequency,
            treasury,
            auction
        );

        IAuctionHouse(auction).initialize(
            token,
            treasury,
            _auctionParams.timeBuffer,
            _auctionParams.reservePrice,
            _auctionParams.minBidIncrementPercentage,
            _auctionParams.duration
        );

        ITreasury(treasury).initialize(governor);

        IGovernor(governor).initialize(treasury, token, _tokenParams.foundersDAO);
    }
}
