# Pin a host key

Pin the node's SSH host key after checking its fingerprint. First-contact enrollment
alone can accept the wrong host. The per-node pin persists across reboots.

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
Owner approval for a build must account for that risk, even on a trusted network.

The image Ansible connection uses paramiko through the PVE node.
Its pinned collection reads `~/.ssh/known_hosts`, not the project trust file.
The current `[paramiko_connection] host_key_auto_add = true` setting permits
first-contact enrollment.

Before an approved build, install the console-verified key in both required
trust stores. Don't enroll an unverified replacement.
The plugin's trust input depends on the approved dependency.
Qualify both connections against unknown and changed keys, without automatic
enrollment or insecure fallback.
See [Build and qualify the golden images](build-base-image.md).

## Next steps

- [SSH key and host-key practices](../ssh.md) for which key belongs on which
  device, and what to rotate.
- [Add a Proxmox VE node](onboard-pve.md) when the pin is one step of a
  larger onboarding.
