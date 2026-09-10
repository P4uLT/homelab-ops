# SOPS and age procedures

This repository encrypts all secrets with SOPS and age. Read this document before you encrypt or decrypt any file.

## 1. Setup on a new machine

1. Install mise.
2. Run `mise install` in the repository root. This command installs SOPS 3.13.3 and age 1.3.2.
3. Copy your age key file to the repository root. Name the file `.age.key.txt`.
4. Run `chmod 600 .age.key.txt`.
5. Do not create a `.env` file for this variable. The committed `mise.toml` sets `SOPS_AGE_KEY_FILE` to the repository key file. The path resolves from any directory, on every machine.
6. Run `mise exec -- sops --decrypt ansible/inventory/servers/group_vars/all/secrets.sops.yaml > /dev/null`. A silent success confirms your setup.

## 2. Encrypt, decrypt, and edit

The file `.sops.yaml` selects the encryption keys. Each file with a name that ends in `.sops.yaml` gets encryption automatically.

1. Create your file with plain values.
2. Run `mise exec -- sops --encrypt --in-place <path>`. The file content becomes encrypted.
3. Run `mise exec -- sops --decrypt <path>` when you need the plain values. Pipe the output to a tool or a review command. Do not write the output to a file.
4. Run `mise exec -- sops edit <path>` to change values. The command opens the decrypted content in your editor. The command encrypts the file again when you close the editor.
5. Confirm the encrypted file with `grep 'ENC\[AES256_GCM' <path>`. The command must show at least one encrypted value.

## 3. Backup key

The backup key file is `.age.key.txt.secours`. Store this file outside the repository on a durable medium. Set its permissions with `chmod 600`.

Every encrypted file accepts the backup key as a second recipient. The backup key alone decrypts every file.

1. Run `mise exec -- age-keygen -y <backup-key-path>`. Compare the output with the recipients in `.sops.yaml`.
2. Run `mise exec -- env SOPS_AGE_KEY_FILE=<backup-key-path> sops --decrypt ansible/inventory/servers/group_vars/all/secrets.sops.yaml > /dev/null`. A silent success confirms the backup key.

## 4. Fresh-clone recovery

A clone without the age key fails on every Ansible run. The failure occurs at variable load, not silently.

1. Clone the repository.
2. Run `mise install`.
3. Put your age key file at the repository root as `.age.key.txt`. Use the main key or the backup key.
4. Run `git status --ignored`. Confirm that git ignores `.age.key.txt`.
5. Run `task -d ansible verify`. A green run confirms the recovery. No `.env` file is needed. The committed `mise.toml` sets the key path.

## Lost main key

1. Copy the backup key to the repository root. Name it `.age.key.txt`.
2. Run `chmod 600 .age.key.txt`.
3. Continue with section 4, step 4. No re-encryption is necessary because both keys are recipients of every file.
