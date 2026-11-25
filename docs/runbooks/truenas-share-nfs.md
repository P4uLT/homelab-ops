# Share a TrueNAS dataset over NFS

Use this page when only NFS clients use a dataset, such as a Proxmox image
library or a backup target.

## Before you start

Check these conditions before you change the configuration:

- The pool and the provisioning access exist. See
  [Bootstrap TrueNAS](bootstrap-truenas.md).
- The NFS service runs. The bootstrap root sets `services.nfs = true`, and the
  plan stops if the service is stopped.
- The bootstrap access key is in the storage tfvars.

## Declare the dataset

Add an entry to `datasets` in `terraform/truenas/gen8/gen8.local.auto.tfvars`:

```hcl
backups = {
  name = "tank/backups"
  nfs = {
    hosts   = ["NFS_CLIENT"]
    comment = "Backup target"
    ro      = false
  }
}
```

Replace the following:

- `backups`: a stable map key. Changing it changes the resource address.
- `NFS_CLIENT`: the client host name or address that needs the export.
  TrueNAS must resolve it.
- `NAS_HOST`: the NAS management address, used in the mount command.

To authorize a subnet, replace `hosts` with `networks = ["192.0.2.0/24"]`.
An export needs at least one host or network. The module rejects `/0`.

## Apply the export

1. Run `task tf:truenas-gen8-plan`.
2. Review the plan. It creates the dataset and its export, and nothing else.
3. Run `task tf:truenas-gen8-apply` after approval.
4. Mount `NAS_HOST:/mnt/tank/backups` on the client.
5. Write and delete a test file as the identity that mounts the export.

## Permissions

An NFS client writes as the identity it maps to. A client that maps to `root`
writes as the dataset owner. Any other identity needs its own access in the
dataset ACL.

## Next steps

- [Set dataset permissions](truenas-dataset-permissions.md) to give another
  identity access.
- [Share over SMB and NFS](truenas-share-multiprotocol.md) to add Windows
  clients to the same dataset.
