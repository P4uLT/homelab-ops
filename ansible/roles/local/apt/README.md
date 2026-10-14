# apt

Manage Advanced Package Tool (APT) packages through a local adoption of WeAreInteractive APT.

## Source and ownership

The role retains upstream tasks, templates, and native inputs.
Read [provenance and local changes](UPSTREAM.md) for the exact source revision and maintenance responsibility.
The upstream [MIT license and copyright notice](LICENSE) apply to the adopted code.

Inventory owns package selection, repositories, cleanup, and upgrade policy.
Call sites supply operational prerequisites without inheriting population upgrades.
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
Image preparation keeps zero explicitly, including the Docker cache-only call.
A recently timestamped but empty sealed cache must not suppress that refresh.
Prerequisite calls keep upgrades off.

## Verification and rollback

Use caller syntax checks, production-profile lint, and `task verify`.
These checks don't establish live package behavior or idempotence.
Applying package operations to managed systems requires owner approval.
No test framework or managed-host deployment accompanies this adoption.

Before deployment, reverting the adoption restores the prior local implementation without changing caller inputs.
After deployment, a code revert doesn't remove packages or restore optional managed configuration.
Review those effects separately before contacting a managed system.
