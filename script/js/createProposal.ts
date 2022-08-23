import yargs from "yargs/yargs";
import { hideBin } from "yargs/helpers";

import {
  Auction__factory,
  Governor__factory,
  Manager__factory,
  Timelock__factory,
  Token__factory,
} from "../../build/typechain/factories";
import { ethers, Signer, Wallet } from "ethers";
import { Provider } from "@ethersproject/abstract-provider";
import { StaticJsonRpcProvider } from "@ethersproject/providers";

async function waitTimestamp(timestampIncrement: number, provider: Provider): Promise<void> {
  const blockNumber = await provider.getBlockNumber();

  let startTime = (await provider.getBlock(blockNumber)).timestamp;
  return new Promise((resolve) => {
    const providerListener = async (blockNumber: number) => {
      const block = await provider.getBlock(blockNumber);
      if (block.timestamp > startTime + timestampIncrement) {
        resolve();
        provider.off('block', providerListener);
      }
    }
    provider.on('block', providerListener);
  })
}

async function run(data: any, signer: Signer) {
  const manager = Manager__factory.connect(data.manager, signer);
  const token = Token__factory.connect(data.token, signer);
  const allAddresses = await manager.getAddresses(token.address);
  const auction = Auction__factory.connect(allAddresses[1], signer);
  const timelock = Timelock__factory.connect(allAddresses[2], signer);
  const governor = Governor__factory.connect(allAddresses[3], signer);

  const proposalArgs: [string[], string[], string[], string] = [
    [auction.address],
    ['0'],
    [auction.interface.encodeFunctionData("setMinimumBidIncrement", [12])],
    "set bid increment to 12",
  ];

  // step 1: create proposal
  await governor.propose(...proposalArgs);

  const coder = new ethers.utils.AbiCoder();
  const id = ethers.utils.keccak256(coder.encode(["address[]", "uint256[]", "bytes[]", "string"], proposalArgs));

  governor.castVote(id, '1');

  await waitTimestamp(14, manager.provider);

  // execute
  await governor.execute(...proposalArgs);
}



yargs(hideBin(process.argv))
  .env("BIDDER")
  .command(
    "bid [tokenid]",
    "place bid",
    (yargs) => {
      return yargs.positional("tokenid", {
        describe: "token id to bid on",
      });
    },
    async (argv) => {
      const signer = new Wallet(argv["private-key"] as string, new StaticJsonRpcProvider(argv.rpc as string));
      await run(argv, signer);
    }
  )
  .option("private-key", {
    alias: "pk",
    description: "private key",
    required: true,
  })
  .option("rpc-url", {
    alias: "rpc",
    description: "rpc-url",
    required: true,
  })
  .option("manager", {
    alias: "m",
    description: "manager address",
    required: true,
  })
  .option("token", {
    alias: "t",
    description: "token address",
    required: true,
  })
  .option("verbose", {
    alias: "v",
    type: "boolean",
    description: "Run with verbose logging",
  })
  .parse();
