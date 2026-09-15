# SSH key and host-key practices

Which key belongs where, and what to rotate. This page is the reference for
every managed host: bare metal, NAS, Raspberry Pi, PVE nodes, and
Terraform-created machines. The procedure that pins a node's host key is in
[Pin a host key](runbooks/pin-host-keys.md).

## Keys

Three rules cover every key in the homelab:

- One automation key per person or tool. Ansible uses a dedicated key.
- One personal key per device. Never copy a private key between devices.
- Normalized key comment: `user@device-purpose`.

## Config entry pattern

Every managed host gets a block in `~/.ssh/config`:

```text
Host <alias>
    HostName <ip>
    IdentitiesOnly yes
    IdentityFile ~/.ssh/<key>
    StrictHostKeyChecking accept-new
```

No `User` line. Ansible takes the user from the encrypted group variables.
For manual logins, pass the user explicitly: `ssh admin@<alias>`.

The image build's Ansible run ignores this file. It connects through paramiko,
which reads neither `~/.ssh/config` nor a password prompt, so the build takes
its key from `pve_ssh_key_path` or from a loaded agent. Everything else,
including every runtime play, goes through this block.

## Terraform-created machines

A golden image carries no key, so a fresh container answers nobody. The node
gives it the automation key and your device key at first contact. The
procedure is in
[Provision an LXC workload](runbooks/provision-pve-ct.md). Its address matters
too. The workload root defaults to DHCP, so a machine you reach often wants a
static address from the git-ignored tfvars.

## Access inventory

Keep an access inventory (node, account, key fingerprint, device) outside
the repository. It's the revocation list for rotation and device loss.

## Rotation

Rotate by event: lost device, departure, suspected leak. The PVE operator
password rotates outside Ansible, because the role creates accounts and does
not change existing passwords.

## Related

- [Pin a host key](runbooks/pin-host-keys.md): the pinning procedure, and the
  two exceptions to it.
- [Add a Proxmox VE node](runbooks/onboard-pve.md): SSH access as one step of
  a node onboarding.
- [SOPS and age procedures](sops.md): the secrets that carry the login.
