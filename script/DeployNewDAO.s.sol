// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// import "forge-std/Script.sol";
// import {IDeployer} from "../src/IDeployer.sol";

// contract SetupDaoScript is Script {
//     IDeployer deployer;

//     function setUp() public {
//         deployer = IDeployer(vm.envAddress("DEPLOYER"));
//     }

//     function run() public {
//         vm.startBroadcast();

//         console2.log(msg.sender);

//         IDeployer.TokenParams memory tokenParams = IDeployer.TokenParams({
//             initStrings: abi.encode(
//                 "Mock Token",
//                 "MOCK",
//                 "This is a mock token",
//                 "ipfs://Qmew7TdyGnj6YRUjQR68sUJN3239MYXRD8uxowxF6rGK8j",
//                 "http://localhost:5000/render"
//             ),
//             foundersDAO: msg.sender,
//             foundersMaxAllocation: 100,
//             foundersAllocationFrequency: 5
//         });

//         IDeployer.AuctionParams memory auctionParams = IDeployer.AuctionParams({reservePrice: 0.01 ether, duration: 10 minutes});

//         IDeployer.GovParams memory govParams = IDeployer.GovParams({
//             timelockDelay: 0,
//             votingDelay: 0, // 1 block
//             votingPeriod: 10,
//             proposalThresholdBPS: 10,
//             quorumVotesBPS: 100
//         });

//         (address _token, address _metadata, address _auction, address _treasury, address _governor) = deployer.deploy(
//             tokenParams,
//             auctionParams,
//             govParams
//         );

//         // now that we have a DAO process a proposal

//         vm.stopBroadcast();
//     }
// }
