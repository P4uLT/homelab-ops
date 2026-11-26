# Share a TrueNAS dataset over NFS

Use this page when only NFS clients use a dataset, such as a Proxmox image
library or a backup target.

See the [TrueNAS access diagram](../truenas-access.md#follow-a-request-to-the-file)
for how the client account, share, and filesystem permissions fit together.

## Before you start

Check these conditions before you change the configuration:

- The pool and the provisioning access exist. See
  [Bootstrap TrueNAS](bootstrap-truenas.md).
- The NFS service runs. The bootstrap root sets `services.nfs = true`, and the
  plan for an enabled export stops if the service is stopped.
- The `terraform-prov` provisioning key is in the storage tfvars.
- For `maproot` or `mapall`, apply `provision_group_lookup = true` in the
  bootstrap root. The storage plan checks that each named account and group
  exists. Unmapped exports don't need this permission for NFS.
- A dedicated non-root account and its group exist on TrueNAS. Use a
  separate account for each repository that needs independent access.

## Declare the dataset

Add an entry to `datasets` in `terraform/truenas/gen8/gen8.local.auto.tfvars`:

```hcl
backups = {
  name = "tank/backups"
  nfs = {
    hosts        = ["NFS_CLIENT"]
    comment      = "Backup target"
    mapall_user  = "BACKUP_USER"
    mapall_group = "BACKUP_GROUP"
    ro           = false
  }
}
```

Replace the following:

- `backups`: a stable map key. Changing it changes the resource address.
- `NFS_CLIENT`: the client host name or address that needs the export.
  TrueNAS must resolve it.
- `BACKUP_USER`: a dedicated non-root TrueNAS account for this export.
  All client requests use this identity. Use this mapping only if the clients
  should act as one account. See [NFS identity mapping](../truenas-access.md#follow-a-request-to-the-file).
- `BACKUP_GROUP`: the TrueNAS group used for these requests.
- `NAS_HOST`: the NAS management address, used in the mount command.

To authorize a subnet, replace `hosts` with `networks = ["192.0.2.0/24"]`.
An export needs at least one host or network. The module rejects `/0`.

## Apply the export

1. Run `task tf:truenas-gen8-plan`.
2. Review the plan. It creates the dataset and its export, and nothing else.
3. Run `task tf:truenas-gen8-apply` after approval.
4. Mount `NAS_HOST:/mnt/tank/backups` on the client.
5. Grant `BACKUP_USER` write and traverse access in the dataset ACL before
   testing writes. Use TrueNAS **Edit Permissions** or declare a `POSIX1E` ACL
   as described in [Set dataset permissions](truenas-dataset-permissions.md).
6. Write and delete a test file from the authorized client.

The export's `ro = false` permits writes but doesn't grant filesystem access.
Without an explicit mapping, TrueNAS squashes client root by default.

## Next steps

- [Set dataset permissions](truenas-dataset-permissions.md) to give another
  identity access.
- [Share over SMB and NFS](truenas-share-multiprotocol.md) to add Windows
  clients to the same dataset.
