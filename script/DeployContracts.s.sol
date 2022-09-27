// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import { IToken, Token } from "../src/token/Token.sol";
import { IAuction, Auction } from "../src/auction/Auction.sol";

import { MetadataRenderer } from "../src/token/metadata/MetadataRenderer.sol";
import { Manager } from "../src/manager/Manager.sol";
import { IManager } from "../src/manager/IManager.sol";
import { Governor } from "../src/governance/governor/Governor.sol";
import { IGovernor } from "../src/governance/governor/IGovernor.sol";
import { Treasury } from "../src/governance/treasury/Treasury.sol";
import { ITreasury } from "../src/governance/treasury/ITreasury.sol";

import { ERC1967Proxy } from "../src/lib/proxy/ERC1967PRoxy.sol";

import { MockTreasury } from "./MockTreasury.sol";
import { MockManager } from "./MockManager.sol";

contract DeployContracts is Script {
    address weth;
    address foundersDAO;

    function setUp() public {
        weth = vm.envAddress("WETH_ADDRESS");
        foundersDAO = vm.envAddress("FOUNDERS_DAO");
    }

    function run() public {
        vm.startBroadcast();
        setupContracts();
        vm.stopBroadcast();
    }

    function setupDAO() public {}

    function setupContracts() public {
        Manager manager = Manager(address(new ERC1967Proxy(address(new MockManager()), abi.encodeWithSelector(MockManager.initialize.selector))));
        address newManagerImpl = address(
            new Manager({
                _tokenImpl: address(new Token(address(manager))),
                _metadataImpl: address(new MetadataRenderer(address(manager))),
                _auctionImpl: address(new Auction(address(manager), weth)),
                _treasuryImpl: address(new MockTreasury(address(this))),
                _governorImpl: address(new Governor(address(manager)))
            })
        );
        manager.upgradeTo(newManagerImpl);

        address mockTreasury = manager.treasuryImpl();

        bytes memory tokeninitStrings = abi.encode(
            "Builder DAO",
            "BUILD",
            "The Builder DAO Governance Token",
            "ipfs://Qmew7TdyGnj6YRUjQR68sUJN3239MYXRD8uxowxF6rGK8j",
            "http://localhost:5000/render"
        );

        IManager.FounderParams[] memory founderParams = new IManager.FounderParams[](1);

        founderParams[0] = IManager.FounderParams({ wallet: foundersDAO, percentage: 2, vestingEnd: block.timestamp + (2 * 60 * 60 * 30 * 12) });

        (address _token, address _metadata, address _auction, address _timelock, address _governor) = manager.deploy(
            founderParams,
            IManager.TokenParams({ initStrings: tokeninitStrings }),
            IManager.AuctionParams({ reservePrice: 0.01 ether, duration: 10 minutes }),
            IManager.GovParams({
                timelockDelay: 2 days,
                votingDelay: 1, // 1 block
                votingPeriod: 1 days,
                proposalThresholdBps: 500,
                quorumThresholdBps: 1000
            })
        );

        address correctTreasury = address(new Treasury(address(manager)));

        address tokenImpl = address(new Token(address(manager)));
        address auctionImpl = address(new Auction(address(manager), weth));

        address managerV2Impl = address(new Manager(tokenImpl, _metadata, auctionImpl, correctTreasury, _governor));

        manager.upgradeTo(managerV2Impl);
        manager.transferOwnership(correctTreasury);

        console2.log("Manager: ");
        console2.log(address(manager));
        console2.log("Manager impl: ");
        console2.log(managerV2Impl);
    }
}
