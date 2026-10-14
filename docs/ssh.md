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

No `User` line. Ansible takes the user from `group_vars/all/vars.yml`, one
value for the whole inventory, and a machine that needs another account
overrides it in its own group_vars. For manual logins, pass the user
explicitly: `ssh admin@<alias>`.

A machine that still answers only as the identity it shipped with is reached
by that identity for one run, at adoption time. The identity is passed to
`task ansible:onboard HOST=<node> IDENTITY=<raw>` and stored nowhere.

The image build's Ansible run ignores this file. It connects through paramiko,
which reads neither `~/.ssh/config` nor a password prompt, so the build takes
its key from `pve_ssh_key_path` or from a loaded agent. A runtime play
connects to the address in the encrypted group variables, so the block above
doesn't match it. Its key comes from the loaded agent or from the SSH
defaults. The block serves manual logins.

## Image-build trust

Build tasks are operational, but the pinned LXC plugin ignores host keys.
The image Ansible connection uses `~/.ssh/known_hosts` through paramiko.
Ordinary Ansible SSH uses `ansible/config/known_hosts`.
The current paramiko setting permits first-contact enrollment.

Preverify the node key in each required trust store before an approved build.
A future plugin must verify its own connection independently.
Its qualification must prove that unknown and changed keys fail without
automatic enrollment. Qualify protected-key or agent access across both paths,
not only a manual SSH login.
See [Pin a host key](runbooks/pin-host-keys.md).

## Terraform-created machines

The golden image carries the fleet account, with its public keys, so a fresh
container answers SSH from birth. The account and its keys come from the
builders' encrypted group secrets, and the build refuses an empty list. Adding
a device means adding its public key there and rebuilding the image chain. The
old key stays trusted in every archive
built before the change. Its address matters too. The workload
root defaults to DHCP, so a machine you reach often wants a static address from
the git-ignored tfvars. The steps are in
[Provision an LXC workload](runbooks/provision-pve-ct.md).

## Access inventory

Keep an access inventory (node, account, key fingerprint, device) outside
the repository. It's the revocation list for rotation and device loss.

## Rotation

Rotate by event: lost device, departure, suspected leak. The PVE operator
password rotates outside Ansible, because the role creates accounts and does
not change existing passwords.

## Related

- [Pin a host key](runbooks/pin-host-keys.md): the pinning procedure, and the
  image-build trust gate.
- [Add a Proxmox VE node](runbooks/onboard-pve.md): SSH access as one step of
  a node onboarding.
- [SOPS and age procedures](sops.md): the secrets that carry the login.
