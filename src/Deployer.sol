// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {IToken, Token} from "./token/Token.sol";
import {IAuctionHouse, AuctionHouse} from "./auction/AuctionHouse.sol";
import {ITreasury, Treasury} from "./governance/treasury/Treasury.sol";
import {IGovernor, Governor} from "./governance/governor/Governor.sol";
import {Proxy} from "./upgrades/proxy/Proxy.sol";

import {IUpgradeManager} from "./upgrades/IUpgradeManager.sol";

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

    struct TokenParams {
        string name;
        string symbol;
        address foundersDAO;
        uint256 foundersMaxAllocation;
        uint256 foundersAllocationFrequency;
    }

    TokenParams token;

    struct AuctionParams {
        uint256 timeBuffer;
        uint256 reservePrice;
        uint256 minBidIncrementPercentage;
        uint256 duration;
    }

    AuctionParams auctionParams;

    struct GovernorParams {
        address treasury;
        address token;
        address vetoer;
    }

    GovernorParams governorParams;

    struct TreasuryParams {
        address governor;
    }

    TreasuryParams treasuryParams;

    struct Deployed {
        address governor;
        address treasury;
        address token;
        address auction;
    }

    Deployed deployed;

    function deploy(
        TokenParams calldata _tokenParams /** auctionParams, */
    ) public {
        deployed.governor = address(new Proxy(governorImpl, ""));
        deployed.treasury = address(new Proxy(treasuryImpl, ""));
        deployed.token = address(new Proxy(tokenImpl, ""));
        deployed.auction = address(new Proxy(auctionImpl, ""));

        // init token, auction, gov, treasury
    }
}
