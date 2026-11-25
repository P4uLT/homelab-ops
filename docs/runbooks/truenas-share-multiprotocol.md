# Share a TrueNAS dataset over SMB and NFS

Use this page when Windows and NFS clients use the same dataset, such as an
image library that Windows fills and Proxmox reads.

TrueNAS documents a multiprotocol preset for this case. The preset gives the
dataset an NFSv4 ACL in `PASSTHROUGH` mode. See the
[dataset preset table](https://www.truenas.com/docs/scale/25.10/scaletutorials/datasets/datasetsscale/#creating-a-dataset).

## Before you start

Check these conditions before you change the configuration:

- The pool and the provisioning access exist. See
  [Bootstrap TrueNAS](bootstrap-truenas.md).
- These bootstrap flags are applied:
  - `provision_smb_shares = true` for the SMB share.
  - `provision_dataset_acls = true` for the dataset ACL.
  - `provision_group_lookup = true` when the ACL names a group.
- The NFS and SMB services run. The plan stops if either is stopped.

## Declare the dataset

Add an entry to `datasets` in `terraform/truenas/gen8/gen8.local.auto.tfvars`:

```hcl
iso = {
  name        = "tank/iso"
  acltype     = "nfsv4"
  share_type  = "MULTIPROTOCOL"
  recordsize  = "1M"
  compression = "lz4"
  filesystem_acl = {
    preset      = "nfs4_group_rw"
    group_names = ["SMB_GROUP"]
  }
  nfs = {
    hosts   = ["NFS_CLIENT"]
    comment = "Proxmox VE image library"
    ro      = false
  }
  smb = {
    name      = "iso"
    purpose   = "MULTIPROTOCOL_SHARE"
    browsable = true
    ro        = false
  }
}
```

Replace the following:

- `SMB_GROUP`: the group that publishes files, such as `smb-users`.
- `NFS_CLIENT`: the NFS client host name or address. TrueNAS must resolve it.
- `NAS_HOST`: the NAS address, used in the Explorer path.

The preset grants the owner full control and each listed group modify access.
Every entry inherits to new children. For different rights, declare
`filesystem_acl.type` and `filesystem_acl.entries` instead.

`acltype = "nfsv4"` is required when the existing dataset reports `inherit`.
A new multiprotocol dataset already receives NFSv4, and the line is harmless.

## Apply the shares

1. Run `task tf:truenas-gen8-plan`.
2. Review the plan. It creates the dataset, the ACL, and both shares. Stop if
   it replaces an existing dataset that holds data.
3. Run `task tf:truenas-gen8-apply` after approval.
4. In Windows Explorer, open `\\NAS_HOST\iso` with the file user, then create
   and delete a test file.
5. In Proxmox, mount the export, write and delete a test file, and register the
   storage with type `iso` only.

## Permissions

An NFS client that maps to `root` writes as the dataset owner. Any other
identity needs its own entry in the ACL. If the identity mapping changes,
review the ACL before relying on the share.

## Known limits

The share preset requires a full administrator when it changes on an existing
share. If an apply fails on `auxsmbconf`, change the preset in TrueNAS with the
administrator account. Then plan again to check for drift. Don't widen the
provisioning key for this change.

## Next steps

- [Set dataset permissions](truenas-dataset-permissions.md) to grant other
  identities access.
- [Recover TrueNAS storage](recover-truenas-storage.md) after a failed
  replacement.
