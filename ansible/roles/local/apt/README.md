# apt

Manage package-index refresh, requested packages, and explicit upgrades on Debian-family systems with Advanced Package Tool (APT).

## Decision and scope

Keep the existing composition of native `ansible.builtin.apt` operations.
Population and prerequisite calls share the mechanism without sharing upgrade policy.

Community roles such as WeAreInteractive APT and DebOps cover repository and broader system configuration.
Reassess those contracts before expanding this interface.
Docker and Proxmox retain their vendor repository and key management.
This refactor doesn't replace a dependency or copy upstream code.

## Interface and ownership

Read the [defaults](defaults/main.yml) and [argument specifications](meta/argument_specs.yml).
Inventory owns population packages and upgrade policy. Call sites supply operational prerequisites.

An empty package list installs nothing. Upgrades remain off unless requested.
Package installation uses `present`, without recommendations.
Upgrades retain existing configuration through `force-confold`.

## Cache freshness

`apt_cache_valid_time` controls the cache lifetime in seconds.
Zero forces refresh, while the existing server default remains unchanged.
Negative values fail before package operations.

An empty cache can still have a recent directory or update-success timestamp.
A positive lifetime can therefore skip refresh on a freshly sealed image.
Image preparation calls pass zero explicitly, including the Docker cache-only call.
That call still supplies an empty package list and disables upgrades.

## Verification

Use syntax checks, production-profile lint, and `task verify`.
Applying package operations to managed systems requires owner approval.
A mocked prerequisite call doesn't prove package installation or cache freshness on a clone.
