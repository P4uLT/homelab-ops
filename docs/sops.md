# SOPS and age procedures

Encrypt tracked secrets with SOPS and age. Commit ciphertext and the recipient
list, not private keys or decrypted values.

## Setup on a new machine

1. Install mise.
2. Run `mise install` in the repository root. This command installs the pinned SOPS and age.
3. Copy your age key to `.age.key.txt` in the repository root.
4. Run `chmod 600 .age.key.txt`.
5. `mise.toml` sets `SOPS_AGE_KEY_FILE` to this file with a directory-independent path. Don't duplicate the setting in `.env`.
6. Run `task sops:decrypt -- ansible/inventory/servers/group_vars/all/secrets.sops.yaml > /dev/null`.
   Expect exit status `0`.

## Encrypt, decrypt, and edit

`.sops.yaml` selects recipients for files ending in `.sops.yaml`.

1. Create your file with plain values.
2. Run `task sops:encrypt -- <path>`. SOPS encrypts the file content.
3. Run `task sops:decrypt -- <path>`. Pipe plaintext to its consumer instead of a file.
4. Run `task sops:edit -- <path>` to edit values. SOPS re-encrypts them when the editor closes.
5. Check the encrypted file with `grep 'ENC\[AES256_GCM' <path>`. The command must show at least one encrypted value.

`task sops:encrypt-all` encrypts plain `*.sops.yaml` files, skipping encrypted
files and `.sops.yaml`. `task sops:check-all` checks encryption without printing values.

## Comments stay at the top

Keep comments at the top level. Nested comments are encrypted, but SOPS doesn't
restore their plaintext in the editor.

## The backup key

The backup key file is `.age.key.txt.secours`. Store this file outside the
repository on a durable medium. Set its permissions with `chmod 600`.

The backup key is a second recipient on each encrypted file and can decrypt
without the main key.

1. Run `age-keygen -y <backup-key-path>`. Compare the output with the recipients in `.sops.yaml`.
2. Run `env SOPS_AGE_KEY_FILE=<backup-key-path> sops --decrypt ansible/inventory/servers/group_vars/all/secrets.sops.yaml > /dev/null`.
   Expect exit status `0`.

## Fresh-clone recovery

Ansible fails during variable loading without the age key.

1. Clone the repository.
2. Run `mise install`.
3. Copy the main or backup key to `.age.key.txt` with mode 600.
   Follow [Setup on a new machine](#setup-on-a-new-machine), steps 3 and 4.
4. Run `git status --ignored`. Check that Git ignores `.age.key.txt`.
5. Run `task verify`.

For step 5, OpenTofu also needs the state passphrase in `.env.tf` to initialize
encrypted state. Ansible uses the age-key path from `mise.toml`.
The first vendor, provider, and plugin downloads need network access.

## Lost main key

Use the backup key without re-encryption:

1. Copy the backup key to `.age.key.txt` in the repository root.
2. Run `chmod 600 .age.key.txt`.
3. Continue at [Fresh-clone recovery](#fresh-clone-recovery), step 4. Both keys are already recipients.

## Next steps

- [Bootstrap the Terraform state backend](runbooks/bootstrap-tf-backend.md):
  the passphrase that `task verify` needs.
- [OVH object storage conventions](object-storage.md): where the state bucket
  lives, and which key opens it.
- [Agent instructions](../AGENTS.md): why every run fails without the key.
