# SOPS and age procedures

This repository encrypts all secrets with SOPS and age. Read this page before
you encrypt or decrypt any file. Git holds the encrypted blobs and the
recipient list, never a key.

## Setup on a new machine

Run these steps once per machine:

1. Install mise.
2. Run `mise install` in the repository root. This command installs the pinned SOPS and age.
3. Copy your age key file to the repository root. Name the file `.age.key.txt`.
4. Run `chmod 600 .age.key.txt`.
5. Don't create a `.env` file for this variable. The committed `mise.toml` sets `SOPS_AGE_KEY_FILE` to the repository key file. The path resolves from any directory, on every machine.
6. Run `task sops:decrypt -- ansible/inventory/servers/group_vars/all/secrets.sops.yaml > /dev/null`. A silent result shows that setup works.

## Encrypt, decrypt, and edit

The file `.sops.yaml` selects the encryption keys. Each file with a name that
ends in `.sops.yaml` gets encryption automatically.

1. Create your file with plain values.
2. Run `task sops:encrypt -- <path>`. The file content becomes encrypted.
3. Run `task sops:decrypt -- <path>` when you need the plain values. Pipe the output to a tool or a review command. Don't write the output to a file.
4. Run `task sops:edit -- <path>` to change values. The command opens the decrypted content in your editor. The command encrypts the file again when you close the editor.
5. Check the encrypted file with `grep 'ENC\[AES256_GCM' <path>`. The command must show at least one encrypted value.

Run `task sops:encrypt-all` to encrypt all plain `*.sops.yaml` files. The task
skips encrypted files and `.sops.yaml`.

Run `task sops:check-all` to check all encrypted files without printing their
values.

## The backup key

The backup key file is `.age.key.txt.secours`. Store this file outside the
repository on a durable medium. Set its permissions with `chmod 600`.

Every encrypted file accepts the backup key as a second recipient. The backup
key alone decrypts every file.

1. Run `age-keygen -y <backup-key-path>`. Compare the output with the recipients in `.sops.yaml`.
2. Run `env SOPS_AGE_KEY_FILE=<backup-key-path> sops --decrypt ansible/inventory/servers/group_vars/all/secrets.sops.yaml > /dev/null`. A silent result shows that the backup key works.

## Fresh-clone recovery

A clone without the age key fails on every Ansible run. The failure happens at
variable load, so it's loud.

1. Clone the repository.
2. Run `mise install`.
3. Put your age key file at the repository root as `.age.key.txt`. Use the main key or the backup key. Set its permissions as in steps 3 and 4 of [Setup on a new machine](#setup-on-a-new-machine).
4. Run `git status --ignored`. Check that Git ignores `.age.key.txt`.
5. Run `task verify`.

Step 5 has two legs. The OpenTofu leg needs the state passphrase from
`.env.tf`. Without it, `tf:init` stops on the encrypted state. The Ansible leg
proves the age recovery on its own, because the committed `mise.toml` sets the
key path. The first run needs network for the vendor, provider, and plugin
downloads.

## Lost main key

The backup key replaces the main key without re-encrypting anything:

1. Copy the backup key to the repository root. Name it `.age.key.txt`.
2. Run `chmod 600 .age.key.txt`.
3. Continue with [Fresh-clone recovery](#fresh-clone-recovery), step 4. No re-encryption is necessary, because both keys are recipients of every file.

## Next steps

- [Bootstrap the Terraform state backend](runbooks/bootstrap-tf-backend.md):
  the passphrase that `task verify` needs.
- [OVH object storage conventions](object-storage.md): where the state bucket
  lives, and which key opens it.
- [Agent instructions](../AGENTS.md): why every run fails without the key.
