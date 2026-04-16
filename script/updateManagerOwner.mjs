#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import path from "node:path";

const CHAIN_CONFIG = {
  1: { alias: "mainnet", label: "ethereum-mainnet" },
  10: { alias: "optimism", label: "optimism-mainnet" },
  8453: { alias: "base", label: "base-mainnet" },
  11155111: { alias: "sepolia", label: "ethereum-sepolia" },
  11155420: { alias: "optimism_sepolia", label: "optimism-sepolia" },
  84532: { alias: "base_sepolia", label: "base-sepolia" },
  7777777: { alias: "zora", label: "zora-mainnet" },
  999999999: { alias: "zora_sepolia", label: "zora-sepolia" },
};

const ADDRESS_RE = /^0x[a-fA-F0-9]{40}$/;

function parseArgs(argv) {
  const args = { write: false, chainIds: [] };

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--write") {
      args.write = true;
      continue;
    }

    if (arg.startsWith("--chain-ids=")) {
      const value = arg.split("=")[1] || "";
      args.chainIds = value
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean);
      continue;
    }

    if (arg === "--chain-ids") {
      const next = argv[i + 1] || "";
      args.chainIds = next
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean);
      i++;
      continue;
    }
  }

  return args;
}

function getOwner(manager, rpcAlias) {
  const out = execFileSync("cast", ["call", manager, "owner()(address)", "--rpc-url", rpcAlias], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();

  if (!ADDRESS_RE.test(out)) {
    throw new Error(`invalid owner response: ${out}`);
  }

  return out;
}

function run() {
  const { write, chainIds } = parseArgs(process.argv.slice(2));
  const repoRoot = process.cwd();
  const addressesDir = path.join(repoRoot, "addresses");

  const selectedChains = (chainIds.length ? chainIds : Object.keys(CHAIN_CONFIG)).filter(
    (id) => CHAIN_CONFIG[id]
  );
  const skipped = chainIds.filter((id) => !CHAIN_CONFIG[id]);

  if (skipped.length > 0) {
    console.log(`Skipping unsupported chain ids: ${skipped.join(", ")}`);
  }

  let changed = 0;
  let checked = 0;

  for (const chainId of selectedChains) {
    const cfg = CHAIN_CONFIG[chainId];
    const filePath = path.join(addressesDir, `${chainId}.json`);

    if (!existsSync(filePath)) {
      console.log(`[${chainId}] ${cfg.label}: addresses file not found, skipping`);
      continue;
    }

    const parsed = JSON.parse(readFileSync(filePath, "utf8"));
    const manager = parsed.Manager;

    if (!ADDRESS_RE.test(manager || "")) {
      console.log(`[${chainId}] ${cfg.label}: invalid Manager address, skipping`);
      continue;
    }

    const owner = getOwner(manager, cfg.alias);
    checked++;

    const previous = parsed.ManagerOwner;
    const isDifferent = previous !== owner;

    if (isDifferent) {
      parsed.ManagerOwner = owner;
      changed++;
      console.log(`[${chainId}] ${cfg.label}: ${previous || "<missing>"} -> ${owner}`);

      if (write) {
        writeFileSync(filePath, `${JSON.stringify(parsed, null, 2)}\n`, "utf8");
      }
    } else {
      console.log(`[${chainId}] ${cfg.label}: up to date (${owner})`);
    }
  }

  console.log(
    `\nChecked ${checked} chain(s), ${changed} change(s)${write ? " written" : " detected"}.`
  );
  if (!write && changed > 0) {
    process.exitCode = 1;
  }
}

run();
