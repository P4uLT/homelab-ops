# Upstream provenance

## Source

This copy adopts the WeAreInteractive Advanced Package Tool (APT) role.

| Field | Value |
| --- | --- |
| Project | [WeAreInteractive APT](https://github.com/weareinteractive/ansible-apt) |
| Revision | `dc45f75895188d0b66c198690e30d07164af2977` |
| Source tree | [Pinned upstream files](https://github.com/weareinteractive/ansible-apt/tree/dc45f75895188d0b66c198690e30d07164af2977) |
| Adoption | Tracked local copy under `ansible/roles/local/apt` |
| License | [Upstream MIT license](LICENSE), retained verbatim with its copyright notice |
| Maintenance | This repository's maintainers own compatibility fixes and source updates |

The tasks, templates, handlers, and defaults come from this revision.
The role retains its existing local name and caller inputs.
Galaxy installation doesn't replace this tracked copy.
The supported repository target remains Debian trixie on the pinned Ansible core.
Upstream platform declarations aren't proof of live compatibility here.

## Intentional differences

- Disable unattended upgrades, periodic operations, autoremove, and autoclean by default.
- Add `apt_manage_config` to make general and periodic configuration optional.
- Default `apt_policy` to null. Write a service-start policy only for an explicit integer exit status.
- Keep `python3-apt` as the dependency. The pinned module doesn't require upstream's aptitude or pycurl packages.
- Keep cache-lifetime validation and `force-confold` for explicit upgrades.
- Accept package names and native dictionaries in local argument specifications.
- Use qualified module names and normalize YAML through `ansible-lint`.
- Replace list-to-boolean conditions with length checks for Ansible compatibility.
- Preserve the native null allowed-origins option when rendering unattended-upgrade configuration.
- Guard cleanup operations when disabled. An empty package operation must not run as an installation.
- Handle package holds only when requested. Compare complete package names and use argument lists for commands.
- Read existing holds in check mode without changing them.
- Apply the recommendation setting to dependency and Debian package installation without changing global APT policy.
- Retain upstream repository, key, preference, proxy, remount, and timer capabilities without enabling them for existing callers.

Read the [role contract](README.md) before changing these controls.
Compare future source updates with the pinned tree and reapply each intentional difference explicitly.
Preserve the license, copyright notice, native input schemas, and current callers.
Run caller syntax checks, production-profile lint, and `task verify` after an update.
Managed-host behavior and idempotence require separate owner-approved verification.
