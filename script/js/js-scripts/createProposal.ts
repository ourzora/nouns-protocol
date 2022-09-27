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
  console.log(`waiting started at ${blockNumber}`);

  let startTime = (await provider.getBlock(blockNumber)).timestamp;
  return new Promise((resolve) => {
    const providerListener = async (blockNumber: number) => {
      const block = await provider.getBlock(blockNumber);
      if (block.timestamp > startTime + timestampIncrement) {
        console.log(`waiting ended at ${blockNumber}`);
        resolve();
        provider.off('block', providerListener);
      }
    }
    provider.on('block', providerListener);
  })
}

async function run(data: any, signer: Signer) {
  console.log({status: 'running'})

  const manager = Manager__factory.connect(data.manager, signer);
  const token = Token__factory.connect(data.token, signer);
  const allAddresses = await manager.getAddresses(token.address);
  console.log({allAddresses});
  const auction = Auction__factory.connect(allAddresses[1], signer);
  const timelock = Timelock__factory.connect(allAddresses[2], signer);
  const governor = Governor__factory.connect(allAddresses[3], signer);

  const proposalArgs: [string[], string[], string[], string] = [
    [auction.address],
    ['0'],
    [auction.interface.encodeFunctionData("setMinimumBidIncrement", [9])],
    "set bid incemet to 9",
  ];

  // step 1: create proposal
  console.log('creating proposal');
  const tx = await governor.propose(...proposalArgs);
  const receipt = await tx.wait();
  let proposalId: any;
  for (let evt of receipt.events || []) {
    proposalId = evt.args![1];
  }

  await waitTimestamp(10, manager.provider);

  const simulateCast = await governor.callStatic.castVote(proposalId, '1');
  console.log(simulateCast);

  await governor.castVote(proposalId, '1');


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
      console.log(argv);
      const signer = new Wallet(argv["private-key"] as string, new StaticJsonRpcProvider(argv.rpc as string));
      console.log('has signer');
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
    type: 'string',
    required: true,
  })
  .option("token", {
    alias: "t",
    description: "token address",
    type: 'string',
    required: true,
  })
  .option("verbose", {
    alias: "v",
    type: "boolean",
    description: "Run with verbose logging",
  })
  .parse();
