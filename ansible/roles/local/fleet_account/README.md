# fleet_account

Prepare sudo and configure accounts through the pinned `robertdebock.users` role.

## Decision and scope

Reuse the vendor's native account schema rather than implementing account management locally.
This composition owns a shared prerequisite and ordering, not another account interface.

Proxmox hypervisors can lack `sudo`, `sudoers`, and `visudo`.
The vendor needs them before configuring sudo rules.
Runtime and image callers share this sequence.

## Interface and ownership

The required list is declared in [argument specifications](meta/argument_specs.yml).
Callers bind their inventory account data to `fleet_account_users`.
Keep credentials in the consuming inventory's encrypted files.

The role rejects an empty list before installing prerequisites.
It calls `apt` with only `sudo` and upgrades off, rather than inheriting population upgrade policy.
It then passes the account list unchanged as the vendor's `users` input.

Don't add local copies of user, key, or sudoers management.
Changes to those operations belong in the pinned vendor or an explicitly maintained adaptation.

## Verification

Use caller syntax checks, production-profile lint, and `task verify`.
Live account changes and access verification require owner approval.
Dependency doubles prove input binding and ordering, not working login access.
