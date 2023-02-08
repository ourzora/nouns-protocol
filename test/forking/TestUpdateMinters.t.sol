// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { Test } from "forge-std/Test.sol";
import { Treasury } from "../../src/governance/treasury/Treasury.sol";
import { Auction } from "../../src/auction/Auction.sol";
import { IAuction } from "../../src/auction/IAuction.sol";
import { Token } from "../../src/token/Token.sol";
import { MetadataRenderer } from "../../src/token/metadata/MetadataRenderer.sol";
import { Governor } from "../../src/governance/governor/Governor.sol";
import { IManager } from "../../src/manager/IManager.sol";
import { Manager } from "../../src/manager/Manager.sol";
import { UUPS } from "../../src/lib/proxy/UUPS.sol";
import { TokenTypesV2 } from "../../src/token/types/TokenTypesV2.sol";
import { GovernorTypesV1 } from "../../src/governance/governor/types/GovernorTypesV1.sol";

contract TestUpdateMinters is Test {
    address internal zoraeth = 0xd1d1D4e36117aB794ec5d4c78cBD3a8904E691D0;
    address internal airdropRecipient = 0xEE5DB9d9D471cA50fa41dcB76c1daf37F37c06aE;
    Manager internal immutable manager = Manager(0xd310A3041dFcF14Def5ccBc508668974b5da7174);
    Token internal immutable token = Token(0xdf9B7D26c8Fc806b1Ae6273684556761FF02d422);
    Auction internal immutable auction = Auction(0x658D3A1B6DaBcfbaa8b75cc182Bf33efefDC200d);
    Governor internal immutable governor = Governor(0xe3F8d5488C69d18ABda42FCA10c177d7C19e8B1a);
    Treasury internal immutable treasury = Treasury(payable(0xDC9b96Ea4966d063Dd5c8dbaf08fe59062091B6D));
    MetadataRenderer internal immutable metadata = MetadataRenderer(0x963ac521C595D3D1BE72C1Eb057f24D4D42CB70b);

    function setUp() public {
        uint256 mainnetFork = vm.createFork(vm.envString("ETH_RPC_MAINNET"), 16585958);
        vm.selectFork(mainnetFork);
    }

    function testUpdateMinters() public {
        ////////      zora.eth upgrades manager and registers upgrades      ////////
        vm.startPrank(zoraeth);
        manager.upgradeTo(0x944F69f0bb504DB4BB8DcF2B8E639F0e04392fA4);
        manager.registerUpgrade(0x5e97b8cfEa96d7571585f79922d134003BD4Dc60, 0x785708d09b89C470aD7B5b3f8ac804cE72B6b282);
        manager.registerUpgrade(0x2661fe1a882AbFD28AE0c2769a90F327850397c6, 0x785708d09b89C470aD7B5b3f8ac804cE72B6b282);
        manager.registerUpgrade(0xb69dC36182Fe5dad045BD4B08Ffb042D10d0fB77, 0xAeD75D1e5c1821E2EC29D5d24b794b13C34c5d63);
        manager.registerUpgrade(0xe6322201ceD0a4D6595968411285A39ccf9d5989, 0xAeD75D1e5c1821E2EC29D5d24b794b13C34c5d63);
        manager.registerUpgrade(0xAc193e2126F0E7734F2aC8DA9D4002935b3c1d75, 0x5a28EEF0eD8cCe44CDa9d7097ecCE041bb51B9D4);
        manager.registerUpgrade(0x26f494Af990123154E7Cc067da7A311B07D54Ae1, 0x5a28EEF0eD8cCe44CDa9d7097ecCE041bb51B9D4);
        manager.registerUpgrade(0xc8F8Ac74600D5A1c1ba677B10D1da0E7e806CF23, 0x3bdAFE0D299168F6ebB6e1B4E1e9702A30F6364D);
        manager.registerUpgrade(0x0B6D2473f54de3f1d80b27c92B22D13050Da289a, 0x3bdAFE0D299168F6ebB6e1B4E1e9702A30F6364D);
        manager.registerUpgrade(0xb42d8E37DCBA5Fe5323C4a6722ba6DEd9E8E84Da, 0x46eA3fd17DEb7B291AeA60E67E5cB3a104FEa11D);
        manager.registerUpgrade(0x9eefEF0891b1895af967fe48C5D7D96E984B96a3, 0x46eA3fd17DEb7B291AeA60E67E5cB3a104FEa11D);
        vm.stopPrank();

        ////////      someone proposes builder dao upgrade and airdrop      ////////
        address[] memory targets = new address[](9);
        targets[0] = address(metadata);
        targets[1] = address(token);
        targets[2] = address(auction);
        targets[3] = address(auction);
        targets[4] = address(auction);
        targets[5] = address(governor);
        targets[6] = address(treasury);
        targets[7] = address(token);
        targets[8] = address(token);

        uint256[] memory values = new uint256[](9);
        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        values[3] = 0;
        values[4] = 0;
        values[5] = 0;
        values[6] = 0;
        values[7] = 0;
        values[8] = 0;

        bytes[] memory calldatas = new bytes[](9);
        calldatas[0] = abi.encodeWithSelector(UUPS.upgradeTo.selector, 0x5a28EEF0eD8cCe44CDa9d7097ecCE041bb51B9D4);
        calldatas[1] = abi.encodeWithSelector(UUPS.upgradeTo.selector, 0xAeD75D1e5c1821E2EC29D5d24b794b13C34c5d63);
        calldatas[2] = abi.encodeWithSelector(Auction.pause.selector);
        calldatas[3] = abi.encodeWithSelector(UUPS.upgradeTo.selector, 0x785708d09b89C470aD7B5b3f8ac804cE72B6b282);
        calldatas[4] = abi.encodeWithSelector(Auction.unpause.selector);
        calldatas[5] = abi.encodeWithSelector(UUPS.upgradeTo.selector, 0x46eA3fd17DEb7B291AeA60E67E5cB3a104FEa11D);
        calldatas[6] = abi.encodeWithSelector(UUPS.upgradeTo.selector, 0x3bdAFE0D299168F6ebB6e1B4E1e9702A30F6364D);
        TokenTypesV2.MinterParams[] memory minterParams = new TokenTypesV2.MinterParams[](1);
        minterParams[0] = TokenTypesV2.MinterParams({ minter: address(treasury), allowed: true });
        calldatas[7] = abi.encodeWithSelector(Token.updateMinters.selector, minterParams);
        calldatas[8] = abi.encodeWithSignature("mintTo(address)", airdropRecipient);

        vm.startPrank(zoraeth);
        vm.roll(block.number + 1);
        bytes32 proposalId = governor.propose(targets, values, calldatas, "airdrop");
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + governor.votingDelay() + 1);
        governor.castVote(proposalId, 1);
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + governor.votingPeriod() + 1);
        vm.stopPrank();
        governor.queue(proposalId);
        vm.warp(block.timestamp + treasury.delay() + 1);

        governor.execute(targets, values, calldatas, keccak256(bytes("airdrop")), zoraeth);

        require(token.balanceOf(airdropRecipient) == 1);
    }
}
