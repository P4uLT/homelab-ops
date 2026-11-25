# fleet_account

Prepare sudo and configure accounts through the pinned `robertdebock.users` role.

## Decision and scope

Proxmox hypervisors can lack `sudo`, `sudoers`, and `visudo`, which the vendor
requires for sudo rules. Use the same prerequisite ordering for onboarding,
runtime, and image calls, with the vendor's account schema.

## Interface and ownership

The [argument specifications](meta/argument_specs.yml) define the required list.
Callers bind their inventory account data to `fleet_account_users`.
Keep credentials in the consuming inventory's encrypted files.

The role rejects an empty list before installing prerequisites.
It installs only `sudo` through `apt`, with upgrades off, then passes the list
unchanged as the vendor's `users` input.

Don't add local copies of user, key, or sudoers management.
Changes to those operations belong in the pinned vendor or an explicitly maintained adaptation.

## Verification

Run `task verify` and the caller's syntax and production-profile lint checks.
These don't establish working login access. Live account changes and access
verification require owner approval.
