# SSH key and host-key practices

SSH policy for bare metal, NAS, Raspberry Pi, PVE nodes, and Terraform-created
machines. Follow [Pin a host key](runbooks/pin-host-keys.md) before connecting.

## Keys

- One automation key per person or tool. Ansible uses a dedicated key.
- One personal key per device. Never copy a private key between devices.
- Normalized key comment: `user@device-purpose`.

## Config entry pattern

For manual logins, add the host to `~/.ssh/config`:

```text
Host <alias>
    HostName <ip>
    IdentitiesOnly yes
    IdentityFile ~/.ssh/<key>
    StrictHostKeyChecking accept-new
```

Omit `User` and pass it explicitly: `ssh admin@<alias>`.
Ansible uses `group_vars/all/vars.yml`, with per-machine overrides in group_vars.
Onboarding uses the original account only for that run:
`task ansible:onboard HOST=<node> IDENTITY=<raw>`. It doesn't store that identity.

Image builds use paramiko, which ignores `~/.ssh/config` and password prompts.
Supply `pve_ssh_key_path` or a loaded agent. Runtime plays connect to encrypted
inventory addresses rather than the alias above, using the agent or SSH defaults.

## Image-build trust

The pinned LXC plugin ignores host keys. Image Ansible uses
`~/.ssh/known_hosts` through paramiko, with first-contact enrollment enabled.
Ordinary Ansible SSH uses `ansible/config/known_hosts`.

Before an approved build, independently verify the key in each required store.
A replacement plugin must verify its own connection and reject unknown or
changed keys without enrollment. Qualify protected-key or agent access on both
paths, following [Pin a host key](runbooks/pin-host-keys.md). Manual SSH access alone isn't sufficient.

## Terraform-created machines

Golden images include the fleet account and public keys from builders'
encrypted group secrets. Builds reject an empty account list.
Add a device's public key there and rebuild the image chain.
Previously built archives still trust the old key.

LXC workloads default to DHCP. For stable SSH addressing, set a static address
in git-ignored tfvars. See [Provision an LXC workload](runbooks/provision-pve-ct.md).

## Access inventory

Keep an access inventory (node, account, key fingerprint, device) outside
the repository. It's the revocation list for rotation and device loss.

## Rotation

Rotate keys after device loss, departure, or suspected leaks.
Rotate the PVE operator password outside Ansible: the role creates accounts
without changing existing passwords.

## Related

- [Pin a host key](runbooks/pin-host-keys.md): the pinning procedure, and the
  image-build trust gate.
- [Add a Proxmox VE node](runbooks/onboard-pve.md): SSH access as one step of
  a node onboarding.
- [SOPS and age procedures](sops.md): the secrets that carry the login.
