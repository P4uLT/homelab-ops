# Pin a host key

Pin a node's SSH host key before Ansible or a manual login contacts it.
Without the pin, the first connection trusts whatever answers, and nothing
verifies the host key.

The pin is per node, and it survives reboots.

## Steps

Get owner approval before the fingerprint scan contacts a node.

1. Read the fingerprint from your machine:
   `task ansible:hostkey -- <node-ip>`.
2. Read the fingerprint on the node console.
3. Compare them. If they match, pin it:
   `task ansible:hostkey-pin -- <node-ip>`.

The pinned keys live in `ansible/config/known_hosts` (git-ignored). Ansible
verifies against this file on every run.

## Image-build risk

The pinned Proxmox LXC plugin disables host-key verification.
Build tasks remain operational, so owner approval must account for this known
risk. A network assumed to be trusted isn't a substitute for verification.

The image Ansible connection uses paramiko through the PVE node.
Its pinned collection reads `~/.ssh/known_hosts`, not the project trust file.
The current `[paramiko_connection] host_key_auto_add = true` setting permits
first-contact enrollment.

Install the independently verified node key in both required trust stores
before an approved live build. Verify each stored fingerprint against
the node console. Don't enroll an unverified replacement key.
The plugin's own trust input depends on the separately approved dependency.
Test unknown and changed keys on both connections, with no automatic enrollment
or insecure fallback.
See [Build and qualify the golden images](build-base-image.md).

## Next steps

- [SSH key and host-key practices](../ssh.md) for which key belongs on which
  device, and what to rotate.
- [Add a Proxmox VE node](onboard-pve.md) when the pin is one step of a
  larger onboarding.
