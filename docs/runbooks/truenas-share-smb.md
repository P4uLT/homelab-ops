# Share a TrueNAS dataset over SMB

Use this page for datasets that people access through SMB from Windows or
Linux, such as shared documents.

See the [TrueNAS access diagram](../truenas-access.md#follow-a-request-to-the-file)
for how the client account, share, and filesystem permissions fit together.

## Before you start

Check these conditions before you change the configuration:

- The pool, the provisioning access, and the SMB group and user exist. See
  [Bootstrap TrueNAS](bootstrap-truenas.md).
- `provision_smb_shares`, `provision_dataset_acls`, and `provision_group_lookup`
  are set to `true` and applied in the bootstrap root.
- The groups `documents-readers` and `documents-editors` exist. Give each
  person their own SMB login. See [Choose an identity](../truenas-access.md#choose-an-identity).
- The SMB service runs. A plan for an enabled share stops if the service is
  stopped.

## Declare the dataset

Add an entry to `datasets` in `terraform/truenas/gen8/gen8.local.auto.tfvars`:

```hcl
documents = {
  name       = "tank/documents"
  share_type = "SMB"
  filesystem_acl = {
    preset = "nfs4_access"
    groups = {
      "documents-readers" = "READ"
      "documents-editors" = "MODIFY"
    }
  }
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
- `NAS_HOST`: the NAS hostname or address, used by SMB clients.

`share_type` is the TrueNAS dataset preset. `SMB` creates the dataset with an
NFSv4 ACL and case-insensitive names. That ACL name refers to the model Windows
uses, not to an NFS share. The preset applies at creation only: changing it
recreates the dataset. Set `ro = true` for a read-only share.

## Apply the share

1. Run `task tf:truenas-gen8-plan`.
2. Review the plan. It creates the dataset, its ACL, and the share.
3. Run `task tf:truenas-gen8-apply` after approval.
4. Connect as an editor. Use `\\NAS_HOST\documents` in Windows Explorer or
   `smb://NAS_HOST/documents` in a Linux file manager with SMB support.
5. Create a test file. Reconnect as a reader and confirm that you can open
   the file but can't change it.
6. If the reader should have access only to this share, try an unrelated share.
   Confirm that the reader can't open it.
7. Delete the test file as an editor.

## Next steps

- [Set dataset permissions](truenas-dataset-permissions.md) to grant the group
  read or write access.
- [Share over SMB and NFS](truenas-share-multiprotocol.md) to serve the same
  dataset over NFS too.
