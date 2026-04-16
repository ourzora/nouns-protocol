# Mainnet V2 Upgrade Runbook

## Scope

This runbook covers:

- Mainnet rollout from `1.2.0` to `2.0.0` for contracts with logic changes: `Manager`, `Token`, `Auction`, `Governor`
- Keeping `MetadataRenderer` and `Treasury` on `1.2.0` (no logic/storage diff from `v1.2.0`)
- Manager owner actions through governance proposal or multisig
- Upgrade path for existing DAOs and expected behavior for newly deployed DAOs

## Current Mainnet Baseline

- Manager proxy: `0xd310a3041dfcf14def5ccbc508668974b5da7174`
- Current manager owner: `0xDC9b96Ea4966d063Dd5c8dbaf08fe59062091B6D`
- Current canonical impls in `addresses/1.json`:
  - Token: `0xAeD75D1e5c1821E2EC29D5d24b794b13C34c5d63`
  - Auction: `0x785708d09b89C470aD7B5b3f8ac804cE72B6b282`
  - Governor: `0x46eA3fd17DEb7B291AeA60E67E5cB3a104FEa11D`
  - MetadataRenderer: `0x5a28EEF0eD8cCe44CDa9d7097ecCE041bb51B9D4` (keep)
  - Treasury: `0x3bdAFE0D299168F6ebB6e1B4E1e9702A30F6364D` (keep)

## Preflight

1. Update `addresses/1.json` with the intended `BuilderDAO` recipient used by the new `Manager` constructor.
2. Export env vars:

```bash
export CHAIN_ID=1
export RPC_URL=<mainnet_rpc>
export PRIVATE_KEY=<deployer_private_key>
export ETHERSCAN_API_KEY=<etherscan_api_key>
export WETH_ADDRESS=0xC02aaA39b223FE8D0A0E5C4F27eAD9083C756Cc2
```

3. Confirm deployment script target: `script/DeployV2Upgrade.s.sol`.
4. Optional: run dry-run without broadcast first.

## Phase 1: Deploy New V2 Implementations

Run:

```bash
yarn deploy:v2-upgrade
```

This deploys:

- `NEW_TOKEN_IMPL`
- `NEW_AUCTION_IMPL`
- `NEW_GOVERNOR_IMPL`
- `NEW_MANAGER_IMPL`

Outputs are written to `deploys/1.version2_upgrade.txt`.

## Phase 2: Update Manager (Root Upgrade Policy)

Manager owner must execute these actions:

1. `Manager.upgradeTo(NEW_MANAGER_IMPL)`
2. Register `Token` upgrades:
   - `0xe6322201ceD0a4D6595968411285A39ccf9d5989 -> NEW_TOKEN_IMPL` (1.1.0)
   - `0xAeD75D1e5c1821E2EC29D5d24b794b13C34c5d63 -> NEW_TOKEN_IMPL` (1.2.0)
3. Register `Auction` upgrades:
   - `0x2661fe1a882AbFD28AE0c2769a90F327850397c6 -> NEW_AUCTION_IMPL` (1.1.0)
   - `0x785708d09b89C470aD7B5b3f8ac804cE72B6b282 -> NEW_AUCTION_IMPL` (1.2.0)
4. Register `Governor` upgrades:
   - `0x9eefEF0891b1895af967fe48C5D7D96E984B96a3 -> NEW_GOVERNOR_IMPL` (1.1.0)
   - `0x46eA3fd17DEb7B291AeA60E67E5cB3a104FEa11D -> NEW_GOVERNOR_IMPL` (1.2.0)

Generate calldata:

```bash
cast calldata "upgradeTo(address)" $NEW_MANAGER_IMPL
cast calldata "registerUpgrade(address,address)" 0xe6322201ceD0a4D6595968411285A39ccf9d5989 $NEW_TOKEN_IMPL
cast calldata "registerUpgrade(address,address)" 0xAeD75D1e5c1821E2EC29D5d24b794b13C34c5d63 $NEW_TOKEN_IMPL
cast calldata "registerUpgrade(address,address)" 0x2661fe1a882AbFD28AE0c2769a90F327850397c6 $NEW_AUCTION_IMPL
cast calldata "registerUpgrade(address,address)" 0x785708d09b89C470aD7B5b3f8ac804cE72B6b282 $NEW_AUCTION_IMPL
cast calldata "registerUpgrade(address,address)" 0x9eefEF0891b1895af967fe48C5D7D96E984B96a3 $NEW_GOVERNOR_IMPL
cast calldata "registerUpgrade(address,address)" 0x46eA3fd17DEb7B291AeA60E67E5cB3a104FEa11D $NEW_GOVERNOR_IMPL
```

Use your manager owner path:

- If owner is DAO treasury: submit one governance proposal containing all calls above.
- If owner is multisig: execute the same calls from multisig in that order.

## Phase 3: Existing DAO Upgrades

Each DAO upgrades itself through its own governance proposal.

Required call sequence per DAO:

1. `Token.upgradeTo(NEW_TOKEN_IMPL)`
2. `Auction.pause()`
3. `Auction.upgradeTo(NEW_AUCTION_IMPL)`
4. `Auction.unpause()`
5. `Governor.upgradeTo(NEW_GOVERNOR_IMPL)`

Notes:

- `Auction` upgrade requires paused state (`whenPaused` in `_authorizeUpgrade`).
- `MetadataRenderer` and `Treasury` are intentionally unchanged in this rollout.

## New DAOs After Manager Update

After manager proxy is upgraded to `NEW_MANAGER_IMPL`, new DAOs deployed via `Manager.deploy(...)` will use:

- Token/Auction/Governor: v2 impls
- MetadataRenderer/Treasury: existing 1.2.0 impls configured in manager constructor

No retrofit proposal is needed for these newly deployed DAOs.

## Verification Checklist

1. Manager proxy implementation equals `NEW_MANAGER_IMPL`.
2. `tokenImpl()`, `auctionImpl()`, `governorImpl()` equal new impl addresses.
3. `metadataImpl()` and `treasuryImpl()` remain unchanged.
4. `isRegisteredUpgrade(base, new)` returns `true` for all six registrations.
5. `getLatestVersions()` returns:
   - token `2.0.0`
   - metadata `1.2.0`
   - auction `2.0.0`
   - treasury `1.2.0`
   - governor `2.0.0`
6. For each upgraded DAO, `getDAOVersions(token)` reflects expected versions.

## Operational Safety

- Run one canary DAO upgrade before broad DAO batch upgrades.
- Keep pause/upgrade/unpause in one DAO proposal where possible.
- Preserve all historical registrations unless there is a clear reason to remove.
- Store all deployed addresses and ownership state updates in JSON manifests.
