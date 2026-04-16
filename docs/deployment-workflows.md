# Deployment Workflows

This doc covers the main deployment and maintenance commands in `package.json`.

## Supported Networks

Only these network aliases are supported in this workspace:

- `mainnet` (`1`)
- `sepolia` (`11155111`)
- `optimism` (`10`)
- `optimism_sepolia` (`11155420`)
- `base` (`8453`)
- `base_sepolia` (`84532`)
- `zora` (`7777777`)
- `zora_sepolia` (`999999999`)

Deprecated networks `4` and `5` are removed.

## Required Env

Minimum env for deploy commands:

- `NETWORK` (must match one alias above)
- `CHAIN_ID`
- `PRIVATE_KEY`

RPC aliases and explorer settings are configured in `foundry.toml` using:

- `[rpc_endpoints]`
- `[etherscan]`

Common env variables used by those sections:

- `MAINNET_RPC_URL`
- `SEPOLIA_RPC_URL`
- `OPTIMISM_RPC_URL`
- `OPTIMISM_SEPOLIA_RPC_URL`
- `BASE_RPC_URL`
- `BASE_SEPOLIA_RPC_URL`
- `ZORA_RPC_URL`
- `ZORA_SEPOLIA_RPC_URL`
- `ETHERSCAN_API_KEY`
- `OPTIMISTIC_ETHERSCAN_API_KEY`
- `BASESCAN_API_KEY`

## Main Deploy Commands

- `yarn deploy:v2-core`

  - Deploy a full fresh v2 core stack (manager proxy + all impls).
  - Output file: `deploys/<CHAIN_ID>.version2_core.txt`.
  - Use for new environments, not mainnet upgrade migration.

- `yarn deploy:v2-upgrade`

  - Deploy only new v2 upgrade impls for existing manager deployments.
  - Deploys: Token, Auction, Governor, Manager impl.
  - Reuses Metadata/Treasury impl addresses from `addresses/<CHAIN_ID>.json`.
  - Output file: `deploys/<CHAIN_ID>.version2_upgrade.txt`.

- `yarn deploy:v2-new`

  - Deploys MerkleReserveMinter plus L2MigrationDeployer.
  - Requires `CrossDomainMessenger` in `addresses/<CHAIN_ID>.json`.
  - Output file: `deploys/<CHAIN_ID>.version2_new.txt`.

- `yarn deploy:erc721-redeem-minter`

  - Deploys ERC721 redeem minter only.
  - Output file: `deploys/<CHAIN_ID>.erc721_redeem_minter.txt`.

- `yarn deploy:dao`

  - Runs `DeployNewDAO.s.sol` sample DAO deployment flow.
  - Intended for controlled deployment/testing flows.

- `yarn deploy:zora`
  - Zora-specific deploy + verification command.
  - Uses custom Blockscout verifier flow intentionally.

## Ownership and Address Maintenance

- `yarn addresses:check-manager-owner`

  - Reads live `Manager.owner()` on supported networks.
  - Compares against `ManagerOwner` in `addresses/*.json`.
  - Non-zero exit when drift exists.

- `yarn addresses:sync-manager-owner`
  - Same as check, but writes updates to `addresses/*.json`.

Optional scoped run:

```bash
source .env && node script/updateManagerOwner.mjs --write --chain-ids 1,8453
```

## Address Book Update Policy

Current policy in this repo:

- Deploy scripts write deployment outputs to `deploys/<CHAIN_ID>.*.txt`.
- Deploy scripts do not auto-write new contract addresses into `addresses/<CHAIN_ID>.json`.
- `addresses/<CHAIN_ID>.json` updates for deployed contract fields remain manual.
- `ManagerOwner` is the only field currently synced automatically via `script/updateManagerOwner.mjs`.

Recommended post-deploy sequence:

1. Run deploy command and capture generated `deploys/*.txt` output.
2. Manually update `addresses/<CHAIN_ID>.json` contract address fields.
3. Run `yarn addresses:sync-manager-owner` to refresh `ManagerOwner`.
4. Commit `deploys/*` and `addresses/*` changes together.

## Example Upgrade Flow

```bash
source .env
export NETWORK=mainnet
export CHAIN_ID=1
yarn deploy:v2-upgrade
yarn addresses:sync-manager-owner
```

Then execute manager owner actions and DAO upgrades using:

- `docs/mainnet-v2-upgrade-runbook.md`
- `docs/manager-ownership-runbook.md`
