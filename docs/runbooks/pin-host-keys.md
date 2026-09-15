# Pin a host key

Pin a node's SSH host key before Ansible or a manual login contacts it.
Without the pin, the first connection trusts whatever answers, and nothing
verifies the host key.

The pin is per node, and it survives reboots.

## Steps

1. Read the fingerprint from your machine:
   `task ansible:hostkey -- <node-ip>`.
2. Read the fingerprint on the node console.
3. Compare them. If they match, pin it:
   `task ansible:hostkey-pin -- <node-ip>`.

The pinned keys live in `ansible/config/known_hosts` (git-ignored). Ansible
verifies against this file on every run.

## The exceptions

The Packer image build doesn't verify the host key. The Proxmox LXC plugin
connects with host-key verification disabled. Treat that link as a trusted
network. The pin above covers Ansible and manual logins only. See
[Build the golden images](build-base-image.md) for the build itself.

The image build's Ansible run is the other one. It reaches the build container
through the PVE node with a paramiko connection, which reads
`~/.ssh/known_hosts` and takes no configurable path. The node's key is learned
on first contact and verified after that, in that file rather than in
`ansible/config/known_hosts`. Compare the fingerprint with the procedure above
the first time, so trust-on-first-use happens once and knowingly.

## Next steps

- [SSH key and host-key practices](../ssh.md) for which key belongs on which
  device, and what to rotate.
- [Add a Proxmox VE node](onboard-pve.md) when the pin is one step of a
  larger onboarding.
