# Set dataset permissions

Use this page to manage a TrueNAS dataset ACL from OpenTofu, for example to
grant a group write access to a share.

## Enable ACL management

Set `provision_dataset_acls = true` in the bootstrap tfvars and apply the
approved role change. This grants filesystem attribute read and write roles to
the storage identity. TrueNAS doesn't scope these roles to one dataset. The
storage identity still can't manage users or groups.

To name a group instead of passing its numeric ID, also set
`provision_group_lookup = true`. This grants account and group read access
through `ACCOUNT_READ`, not write access.

## Use the NFSv4 preset

For a share with one or more publishing groups, declare the preset:

```hcl
filesystem_acl = {
  preset      = "nfs4_group_rw"
  group_names = ["SMB_GROUP"]
}
```

Replace `SMB_GROUP` with the group that publishes files, such as `smb-users`.

The preset grants the owner full control and each group modify access. Other
identities get nothing, and every entry inherits to new children. The dataset needs an NFSv4 ACL: create it with
`share_type = "SMB"` or `"MULTIPROTOCOL"`, or set `acltype = "nfsv4"`.

Name one group with `group_gid`, `group_name`, or `group_names`. Use only one of
them. The module resolves names and sends only numeric IDs to the ACL.

## Declare a custom ACL

Set `filesystem_acl.type` to match the dataset, `POSIX1E` or `NFS4`, then list
the full ACL in `filesystem_acl.entries`:

```hcl
filesystem_acl = {
  type = "NFS4"
  entries = [
    { tag = "owner@", type = "ALLOW", basic_perms = "FULL_CONTROL", basic_flags = "INHERIT" },
    { tag = "GROUP", type = "ALLOW", group = "SMB_GROUP", basic_perms = "MODIFY", basic_flags = "INHERIT" },
  ]
}
```

Name an identity with `group` or `user`, or pass a numeric `id`. Avoid `who`:
it stores the name, which the provider resolves again on every refresh.

For a POSIX ACL, `inherit_access = true` also writes each access entry as a
default entry, so new children inherit the same rights.

## Apply the ACL

1. Run `task tf:truenas-gen8-plan`.
2. Review the current permissions in TrueNAS. The resource replaces the full ACL
   on that path.
3. Review the planned ACL. By default it doesn't change existing child files
   or directories. Set `recursive = true` to replace their ACLs too, and
   `traverse = true` to cross child datasets.
4. Run `task tf:truenas-gen8-apply` after approval.

Don't bypass deletion protection to stop managing an ACL. Destroying the
resource removes the extended ACL entries on the NAS. To keep the ACL without
managing it, back up the state and use a reviewed state-only removal.

## Next steps

- [Share over SMB](truenas-share-smb.md) or
  [share over SMB and NFS](truenas-share-multiprotocol.md) to publish the
  dataset.
- [Recover TrueNAS storage](recover-truenas-storage.md) after a failed
  replacement.
