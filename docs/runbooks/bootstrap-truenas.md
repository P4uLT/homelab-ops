# Bootstrap TrueNAS on the Gen8

Use this runbook for a fresh TrueNAS Community Edition 25.10 installation.
OpenTofu manages storage and access, not the installation or its network
access. The roots use the
[official TrueNAS provider](https://github.com/truenas/terraform-provider-truenas/tree/v1.9.3).

## Prepare access and disks

Get owner approval before contacting TrueNAS, including for a plan. Confirm the
management endpoint and trust its TLS certificate. For a private CA, set
`truenas_ca_cert` to the local certificate file in `PEM` format. Don't disable
certificate verification.

1. Create a bootstrap API key for the initial TrueNAS administrator.
2. Check the data disk serial numbers against the TrueNAS disk inventory.
   Exclude the boot disk. Creating a pool erases the selected disks. The
   `pool` object defaults build `tank` as one RAIDZ2 vdev. Set `pool.layout`
   to `MIRROR` or `RAIDZ` for a different vdev.
3. Copy the example in `terraform/bootstrap/truenas/gen8/` to
   `gen8.local.auto.tfvars` in that root. Restrict the file to its owner.
   Set `truenas_host` to the management hostname or address, without a scheme
   or path. Enter the bootstrap key and the disk serials.
4. Configure the [state backend](../../terraform/BACKEND.md), then run
   `task tf:init`. The roots store separate encrypted states in S3.

## Create the pool and provisioning access

```sh
task tf:truenas-gen8-bootstrap-plan
```

Review the plan before apply. Apply presents a fresh plan. For a new NAS,
expect the `tank` pool with one RAIDZ2 vdev, provisioning group, user,
privilege, and service API key. Also expect the NFS and `cifs` services. The `cifs` service handles
Server Message Block shares. This step doesn't create a share or grant file
access to `terraform-prov`. Stop if the plan deletes or replaces anything.

`prevent_destroy` protects the pool while the resource stays in configuration.
Don't remove the resource block as a way to bypass that check.

After approval, run `task tf:truenas-gen8-bootstrap-apply`. Review the fresh
plan before confirming.

If you already applied the bootstrap without the API key resource, expect only
`truenas_api_key.provisioner` to be added. Stop if the plan changes the pool.
If you issued a separate service key by hand, revoke it only after validating
the new one.

The provider stores the generated `terraform-prov` key in encrypted bootstrap
state. The `api_key_value` output is sensitive, but `-raw` prints the key.
Retrieve it only in a private terminal, not in a recorded session or CI log:

```sh
task tf:truenas-gen8-bootstrap-output -- -raw api_key_value
```

Copy the example in `terraform/truenas/gen8/` to `gen8.local.auto.tfvars` in
that root. Restrict the file to its owner. Enter the service key, not the admin
key.

The bootstrap `services` object uses the native names `nfs` and `cifs`. Set a
value to `false` to stop the service and disable it at boot without removing
its shares. Both services default to `true` on the Gen8.

A plan for an enabled share stops if its service isn't running. You can
still plan to disable a share while its service is stopped.

## Manage file accounts

Rotate a password by changing the local secret and incrementing that user's
`password_wo_version`. Changing `full_name` is safe. Changing `username`
replaces the account with the pinned provider.

To swap a login without losing access, create the new account in the same group
and test it. Remove the old account in a separate reviewed apply. Keep map keys
stable for existing accounts and groups.

## Share the first dataset

Choose the page that matches the clients:

| Clients | Page |
| --- | --- |
| NFS only | [Share over NFS](truenas-share-nfs.md) |
| SMB only | [Share over SMB](truenas-share-smb.md) |
| SMB and NFS | [Share over SMB and NFS](truenas-share-multiprotocol.md) |
| No network client | Omit `nfs` and `smb` in the dataset entry |

Each page lists its bootstrap flags, the dataset entry, and the checks after
apply.

## Add more datasets

Add an entry to `datasets` in the storage tfvars, then follow the page for its
clients. Keep the map key stable: changing it changes the resource address.
Set a share's `enabled` to `false` to disable it without deleting it.

`share_type` selects the TrueNAS dataset preset at creation. Without it, the
dataset uses `GENERIC`. Changing it recreates the dataset.

| `share_type` | Use it for | ACL |
| --- | --- | --- |
| `GENERIC` | NFS-only datasets, iSCSI, data for local apps | POSIX, case-sensitive |
| `SMB` | Datasets only Windows clients use | NFSv4, restricted, case-insensitive |
| `MULTIPROTOCOL` | Datasets shared over SMB and NFS | NFSv4, `PASSTHROUGH` |
| `APPS` | Application data with no share | NFSv4, `PASSTHROUGH`, extra entry for the apps group |

Set quota and reservation values in bytes. Supply any dataset key or passphrase
in `dataset_encryption_secrets`, keyed by the dataset's map key. These inputs
are local, ephemeral, and passed to write-only attributes. Store a recovery copy
outside the NAS before creating an encrypted dataset. Review create-only
settings such as the encryption mode before apply.

Keep `protect = true` on every dataset that holds data. The module rejects
replacements that would destroy a dataset while its resource stays configured.

## Install the RustFS application

To install RustFS as the one application on the NAS:

1. Add a `rustfs` entry to `datasets` with `share_type = "APPS"`.
2. Mint the admin key pair outside OpenTofu and store it in a password
   manager. Use an access key of 3 to 20 characters and a secret key of 8 to
   40.
3. Enter the pair in both Gen8 tfvars files. The storage root and the RustFS
   root read the same values.
4. Fill the `rustfs_app_*` block in the storage tfvars. Set the version to
   chart `1.1.46`, which packages RustFS `1.0.6`. Confirm the catalog still
   offers that version.
5. Set `rustfs_app_certificate_id` to an existing TrueNAS certificate. The
   endpoint name must match it. Without a certificate the chart serves HTTP.
6. Set `rustfs_app_api_bind_ip` to one approved interface address. Open the
   API port only to the operator and Talos networks.
7. Run `task tf:truenas-gen8-plan`, review it, and apply.
8. Run `task tf:rustfs-gen8-plan`, review it, and apply.

Turning the gate off after install plans removal. That's a teardown, not a
way to stop the application.

Get owner approval for every live step: plan, apply, and check. Mock tests
don't prove the application's behavior. Check the result after each apply:

- The installed chart version matches the pin, and the application is healthy.
- The API answers over verified HTTPS on the approved address and port.
- The console port isn't published.
- User `568` can write to `/mnt/tank/rustfs`.
- Each key performs its required actions on its own bucket.
- Each key fails to reach the other two buckets.
- No key can administer its own bucket.
- Every quota is positive and leaves headroom on `tank` for snapshots and the
  other datasets.

## Next

- [Set dataset permissions](truenas-dataset-permissions.md) to grant group or
  user access through OpenTofu.
- [Recover TrueNAS storage](recover-truenas-storage.md) after a reinstall, a
  deleted dataset, or a failed replacement.
