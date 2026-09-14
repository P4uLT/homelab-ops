# Pin a host key

Pin a node's SSH host key before Ansible or a manual login contacts it.
Without the pin, the first connection trusts whatever answers, and the
host-key check protects nothing.

The pin is per node, and it survives reboots.

## Steps

1. Read the fingerprint from your machine:
   `task ansible:hostkey -- <node-ip>`.
2. Read the fingerprint on the node console.
3. Compare them. If they match, pin it:
   `task ansible:hostkey-pin -- <node-ip>`.

The pinned keys live in `ansible/config/known_hosts` (git-ignored). Ansible
verifies against this file on every run.

## The one exception

The Packer image build doesn't verify the host key. The Proxmox LXC plugin
connects with host-key verification disabled. Treat that link as a trusted
network. The pin above covers Ansible and manual logins only. See
[Build the golden images](build-base-image.md) for the build itself.

## Next steps

- [SSH key and host-key practices](../ssh.md) for which key belongs on which
  device, and what to rotate.
- [Add a Proxmox VE node](onboard-pve.md) when the pin is one step of a
  larger onboarding.
