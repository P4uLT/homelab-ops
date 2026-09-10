# SSH management

Key and host-key practices for every managed host: bare metal, NAS,
Raspberry Pi, PVE nodes, and Terraform-created machines.

## Host key pinning

Before the first managed contact, pin the host key:

1. Read the fingerprint from your machine: `task ansible:hostkey -- <node-ip>`.
2. Read the fingerprint on the node console.
3. Both match? Pin it: `task ansible:hostkey-pin -- <node-ip>`.

The pinned keys live in `ansible/config/known_hosts` (git-ignored).
Ansible verifies against this file on every run.

## Keys

- One automation key per person or tool. Ansible uses a dedicated key.
- One personal key per device. Never copy a private key between devices.
- Normalized key comment: `user@device-purpose`.

## Config entry pattern

```text
Host <alias>
    HostName <ip>
    IdentitiesOnly yes
    IdentityFile ~/.ssh/<key>
    StrictHostKeyChecking accept-new
```

No `User` line. Ansible takes the user from the encrypted group variables.
For manual logins, pass the user explicitly: `ssh admin@<alias>`.

## Access inventory

Keep an access inventory (node, account, key fingerprint, device) outside
the repository. It is the revocation list for rotation and device loss.

## Rotation

Rotate by event: lost device, departure, suspected leak. The PVE operator
password rotates outside Ansible (the role creates accounts, it does not
change existing passwords).
