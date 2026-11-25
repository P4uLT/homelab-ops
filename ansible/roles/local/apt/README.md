# apt

Manage Advanced Package Tool (APT) packages with a local copy of WeAreInteractive APT.

## Source and ownership

Read [provenance and local changes](UPSTREAM.md) for the source revision and maintenance policy.
The role retains upstream tasks, templates, and native inputs.
The upstream [MIT license and copyright notice](LICENSE) apply to the adopted code.

Inventory selects packages, repositories, cleanup, and upgrades.
Prerequisite calls don't inherit population upgrades.
Docker and Proxmox retain their vendor repository and key management.

## Interface

Read the [defaults](defaults/main.yml) and [argument specifications](meta/argument_specs.yml).
The [upstream documentation](https://github.com/weareinteractive/ansible-apt/blob/dc45f75895188d0b66c198690e30d07164af2977/README.md) describes the native schemas.

Existing callers keep `apt_packages`, `apt_upgrade`, and `apt_cache_valid_time`.
Package entries accept names or upstream dictionaries of package options.
The package state defaults to `present`, without recommendations.
An empty list selects no population packages.
The dependency step ensures `python3-apt`, which the pinned module requires.
Upgrades remain off unless requested and retain existing configuration through `force-confold`.

## Optional configuration

These controls are off by default:

| Input | Effect when enabled |
| --- | --- |
| `apt_manage_config` | Write the upstream general and periodic APT configuration |
| `apt_policy` | An integer writes the corresponding `policy-rc.d` exit status. Null leaves the file untouched |
| `apt_autoremove` | Remove unused dependency packages |
| `apt_autoclean` | Clean obsolete downloaded packages |
| `apt_unattended_upgrades` | Install and configure unattended upgrades |
| `apt_periodic` | Enable periodic operations in the managed APT configuration |

Repository, key, preference, proxy, remount, and timer inputs retain their native upstream meanings.
Use inventory to request them explicitly.
To configure automatic updates, select `apt_manage_config`, `apt_periodic`, and `apt_unattended_upgrades` together.
Review origins, schedules, cleanup, and reboot settings before enabling them.

Disabling a control leaves existing files and services in place.
It doesn't undo configuration from an earlier apply or another tool.
Repository tasks retain legacy `apt_key` and `apt_repository` modules.
Review signing-key scope before enabling them. Their deprecation needs a future compatibility review.

## Cache freshness

`apt_cache_valid_time` controls the cache lifetime in seconds.
Zero forces refresh. Negative values fail before package operations.
Use `apt_cache_valid_time: 0` for image preparation, including Docker's cache-only
call: a sealed cache can be empty despite a recent timestamp. Keep prerequisite upgrades off.

## Verification and rollback

Run `task verify` and the caller's syntax and production-profile lint checks.
Live package behavior and idempotence need separate, owner-approved verification.

Before deployment, reverting the adoption restores the prior role without changing caller inputs.
After deployment, a code revert doesn't remove packages or restore optional managed configuration.
Review those effects separately before contacting a managed system.
