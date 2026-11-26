# Set dataset permissions

Use this page to manage a TrueNAS dataset ACL from OpenTofu, for example to
grant a group write access to a share. Before setting rights, see
[who owns the dataset](../truenas-access.md#choose-who-owns-the-dataset).
This module sets ACL entries, not the owning user or group.

## Enable ACL management

Set `provision_dataset_acls = true` in the bootstrap tfvars and apply the
approved role change. This grants filesystem attribute read and write roles to
the storage identity. TrueNAS doesn't scope these roles to one dataset. The
storage identity still can't manage users or groups.

To use named users or groups in the ACL, also set
`provision_group_lookup = true`. This grants account and group read access
through `ACCOUNT_READ`, not write access.

## Use the NFSv4 preset

Declare one right per existing account or group. Use `users`, `groups`, or both:

```hcl
filesystem_acl = {
  preset = "nfs4_access"
  groups = {
    "iso-publishers" = "MODIFY"
  }
  users = {
    "pve-iso-smb" = "READ"
  }
}
```

Replace the example names with your TrueNAS accounts and groups. The module
resolves them to numeric IDs. The owner keeps full control. Entries inherit to new
files and directories.

| Right | What the user or group can do |
| --- | --- |
| `READ` | List and traverse directories and read files. |
| `MODIFY` | Read, create, change, and delete files without managing ACLs. |

A user can gain access through multiple groups. Keep reader accounts out of
publisher groups if those accounts must not write. Share settings such as
NFS read-only access apply separately.

Use the preset on a dataset with an NFSv4 ACL. For a new dataset, use
`share_type = "SMB"` or `"MULTIPROTOCOL"`, or set `acltype = "nfsv4"`.
Changing the ACL type of an existing dataset can require replacement.

If you used `nfs4_group_access`, change only the preset name to `nfs4_access`.
If you used `nfs4_group_rw`, move each named group into `groups` with
`"MODIFY"`. For a numeric group ID, use a custom ACL with an explicit `id`
and include the owner entry.

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

1. Get owner approval before contacting TrueNAS or running a plan.
2. For an existing dataset, check its owner, owning group, and ACL in
   **Datasets > Permissions**. The resource replaces the full ACL on that path.
3. Run `task tf:truenas-gen8-plan` and review the planned ACL. By default, it
   doesn't change existing files or directories below the dataset root.
   Set `recursive = true` to replace their ACLs too. With recursion enabled,
   `traverse = true` also crosses child datasets.
4. Run `task tf:truenas-gen8-apply` after approval.
5. Check the owner, owning group, and ACL in **Datasets > Permissions**.
6. Test allowed and denied access with the actual client accounts.

Don't bypass deletion protection to stop managing an ACL. Destroying the
resource removes the extended ACL entries on the NAS. To keep the ACL without
managing it, back up the state and use a reviewed state-only removal.

## Next steps

- [Share over SMB](truenas-share-smb.md) or
  [share over SMB and NFS](truenas-share-multiprotocol.md) to publish the
  dataset.
- [Recover TrueNAS storage](recover-truenas-storage.md) after a failed
  replacement.
