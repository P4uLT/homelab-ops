# Share a TrueNAS dataset over SMB

Use this page when only Windows clients use a dataset, such as shared
documents.

## Before you start

Check these conditions before you change the configuration:

- The pool, the provisioning access, and the SMB group and user exist. See
  [Bootstrap TrueNAS](bootstrap-truenas.md).
- `provision_smb_shares = true` is applied in the bootstrap root.

## Declare the dataset

Add an entry to `datasets` in `terraform/truenas/gen8/gen8.local.auto.tfvars`:

```hcl
documents = {
  name       = "tank/documents"
  share_type = "SMB"
  smb = {
    name      = "documents"
    purpose   = "DEFAULT_SHARE"
    browsable = true
    ro        = false
  }
}
```

Replace the following:

- `documents`: a stable map key, also used as the share name here. Changing the
  key changes the resource address.
- `NAS_HOST`: the NAS address, used in the Explorer path.

`share_type` is the TrueNAS dataset preset. `SMB` creates the dataset with an
NFSv4 ACL and case-insensitive names. That ACL name refers to the model Windows
uses, not to an NFS share. The preset applies at creation only: changing it
recreates the dataset. Set `ro = true` for a read-only share.

## Apply the share

1. Run `task tf:truenas-gen8-plan`.
2. Review the plan. It creates the dataset and the share.
3. Run `task tf:truenas-gen8-apply` after approval.
4. In Windows Explorer, open `\\NAS_HOST\documents` with the file user.
5. Create and delete a test file to confirm the access.

## Permissions

The share setting grants no file access. Grant the SMB group its rights in the
dataset ACL.

## Next steps

- [Set dataset permissions](truenas-dataset-permissions.md) to grant the group
  read or write access.
- [Share over SMB and NFS](truenas-share-multiprotocol.md) to serve the same
  dataset over NFS too.
