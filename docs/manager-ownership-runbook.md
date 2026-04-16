# Manager Ownership Runbook

## What Manager Ownership Controls

Manager ownership is the root protocol upgrade policy control.

Manager owner can:

- Upgrade manager proxy implementation via `upgradeTo(...)`
- Allow or revoke DAO upgrade paths via `registerUpgrade(...)` and `removeUpgrade(...)`

Manager owner does not directly upgrade all DAO proxies. Each DAO still executes its own `upgradeTo(...)` calls through that DAO governance flow.

## Ownership Functions

Manager inherits `Ownable` and supports:

- One-step transfer: `transferOwnership(address newOwner)`
- Two-step transfer (recommended):
  - `safeTransferOwnership(address newOwner)`
  - `acceptOwnership()` by pending owner
- Optional cancel before acceptance: `cancelOwnershipTransfer()`

## Recommended Policy

Prefer two-step ownership transfer for production networks.

Why:

- Avoids accidental transfer to wrong address
- Gives an explicit acceptance checkpoint
- Produces clear audit trail (`OwnerPending`, then `OwnerUpdated`)

## Execution Paths

## Path A: Current owner is governance/treasury

1. Create governance proposal that calls manager:
   - `safeTransferOwnership(NEW_OWNER)`
2. Execute proposal.
3. From `NEW_OWNER`, call:
   - `acceptOwnership()`
4. Verify owner state and events.

## Path B: Current owner is multisig

1. Execute multisig tx calling manager:
   - `safeTransferOwnership(NEW_OWNER)`
2. From `NEW_OWNER`, call:
   - `acceptOwnership()`
3. Verify owner state and events.

## One-Step Transfer (only if required)

If your process requires immediate transfer:

- current owner calls `transferOwnership(NEW_OWNER)`

Use this only when operationally necessary.

## Calldata Helpers

```bash
cast calldata "safeTransferOwnership(address)" <NEW_OWNER>
cast calldata "acceptOwnership()"
cast calldata "transferOwnership(address)" <NEW_OWNER>
cast calldata "cancelOwnershipTransfer()"
```

## Verification Steps

1. Read current owner:

```bash
cast call <MANAGER_PROXY> "owner()(address)" --rpc-url <RPC_URL>
```

2. Read pending owner:

```bash
cast call <MANAGER_PROXY> "pendingOwner()(address)" --rpc-url <RPC_URL>
```

3. Check events on executed tx:

- `OwnerPending(owner, pendingOwner)` after `safeTransferOwnership`
- `OwnerUpdated(prevOwner, newOwner)` after `acceptOwnership` or `transferOwnership`
- `OwnerCanceled(owner, canceledOwner)` if cancelled

## Failure Modes

- If `acceptOwnership()` is called by non-pending address, tx reverts with `ONLY_PENDING_OWNER()`.
- If old owner wants to abort before acceptance, call `cancelOwnershipTransfer()`.
- Do not queue manager upgrade and ownership transfer in conflicting order; decide expected owner at execution time first.

## JSON Manifest Updates

Store ownership state in `addresses/<chain>.json`.

Recommended keys:

- `ManagerOwner`
- `ManagerPendingOwner`
- `ManagerOwnerLastUpdatedBlock`
- `ManagerOwnerLastUpdatedTx`

Example:

```json
{
  "Manager": "0xd310a3041dfcf14def5ccbc508668974b5da7174",
  "ManagerImpl": "0x...",
  "ManagerOwner": "0x...",
  "ManagerPendingOwner": "0x0000000000000000000000000000000000000000",
  "ManagerOwnerLastUpdatedBlock": 0,
  "ManagerOwnerLastUpdatedTx": "0x..."
}
```

## Operational Checklist

1. Confirm `NEW_OWNER` is correct chain/address.
2. Execute `safeTransferOwnership(NEW_OWNER)` via active owner path.
3. Confirm `pendingOwner == NEW_OWNER`.
4. Have `NEW_OWNER` execute `acceptOwnership()`.
5. Confirm `owner == NEW_OWNER` and `pendingOwner == 0x0`.
6. Update `addresses/<chain>.json` with owner metadata.
7. Record tx hash and block in deployment notes.
