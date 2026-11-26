# Share a TrueNAS dataset over SMB and NFS

Use this page when Windows and NFS clients use the same dataset, such as an
image library that Windows fills and Proxmox reads.

TrueNAS documents a multiprotocol preset for this case. The preset gives the
dataset an NFSv4 ACL in `PASSTHROUGH` mode. See the
[dataset preset table](https://www.truenas.com/docs/scale/25.10/scaletutorials/datasets/datasetsscale/#creating-a-dataset).
That table is the 25.10 version, the release this page was checked against.
Unversioned TrueNAS pages can describe a different preset.

See the [TrueNAS access diagram](../truenas-access.md#follow-a-request-to-the-file)
for how the client account, share, and filesystem permissions fit together.

## Before you start

Check these conditions before you change the configuration:

- The pool and the provisioning access exist. See
  [Bootstrap TrueNAS](bootstrap-truenas.md).
- These bootstrap flags are applied:
  - `provision_smb_shares = true` for the SMB share.
  - `provision_dataset_acls = true` for the dataset ACL.
  - `provision_group_lookup = true` to resolve names in ACLs and NFS mappings.
- The accounts and groups in the
  [bootstrap example](../../terraform/bootstrap/truenas/gen8/gen8.local.auto.tfvars.example)
  exist. The `iso-publisher` SMB account belongs to `iso-publishers`.
  The non-root `iso-reader` account has `iso-readers` as its primary group.
- The NFS and SMB services run. A plan for an enabled share stops if its
  service is stopped.

## Declare the dataset

Copy the
[storage example](../../terraform/truenas/gen8/gen8.local.auto.tfvars.example)
to `terraform/truenas/gen8/gen8.local.auto.tfvars` if that file doesn't exist.
Otherwise, add this entry to its `datasets` map:

```hcl
iso = {
  name        = "tank/iso"
  share_type  = "MULTIPROTOCOL"
  recordsize  = "1M"
  compression = "lz4"
  filesystem_acl = {
    preset = "nfs4_access"
    groups = {
      "iso-readers"    = "READ"
      "iso-publishers" = "MODIFY"
    }
  }
  nfs = {
    hosts         = ["NFS_CLIENT"]
    comment       = "Proxmox VE image library"
    maproot_user  = "iso-reader"
    maproot_group = "iso-readers"
    ro            = true
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

- `NAS_HOST`: the NAS management hostname or address. Also use it in Explorer.
- `PROVISIONING_API_KEY`: the `terraform-prov` key from the bootstrap output.
- `NFS_CLIENT`: the Proxmox client hostname or address. TrueNAS must resolve it.

If you use other identity names, update both the ACL groups and the NFS
mapping to match the accounts and groups on TrueNAS.

A new multiprotocol dataset receives an NFSv4 ACL. For an existing dataset,
check its effective ACL type and keep its current `acltype` setting. Changing
that setting can trigger replacement.

## Apply the shares

1. Run `task tf:truenas-gen8-plan`.
2. Review the plan. It creates the dataset, the ACL, and both shares. Stop if
   it replaces an existing dataset that holds data.
3. Run `task tf:truenas-gen8-apply` after approval.
4. Open `\\NAS_HOST\iso` in Windows Explorer with the SMB user.
5. Create `template/iso/` through SMB before adding the read-only export to
   Proxmox. Copy a test `.iso` file there.
6. In Proxmox, add the export with content type `iso` only. Check that
   Proxmox can list `template/iso/` and open the test file. Confirm that
   writing through NFS is denied.

## How Proxmox gets read access

| Setting | What it controls |
| --- | --- |
| `maproot_user` | Maps client `root` to the TrueNAS user `iso-reader`. |
| `maproot_group` | Sets the group for the same mapping to `iso-readers`. |
| `filesystem_acl.groups` | Grants `iso-readers` permission to list, traverse, and read files. Grants `iso-publishers` permission to modify them. |
| `nfs.ro` | Blocks writes through the NFS export, even if the filesystem ACL permits them. |

This example sets `maproot_group` because the ACL grants `READ` to the group
`iso-readers`. If an explicit ACL grants `READ` directly to `iso-reader`,
`maproot_user` is enough for that grant.

For a dataset whose ACL OpenTofu doesn't already manage, you can omit
`filesystem_acl` and use its existing permissions. Check that the mapped
user can read the files. See [how TrueNAS checks access](../truenas-access.md#follow-a-request-to-the-file).

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
