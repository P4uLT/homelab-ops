# Diagnose TrueNAS share access

Use this procedure when a client can't open or write a file, or when an
OpenTofu plan fails while reading TrueNAS. Get owner approval before contacting
TrueNAS or running a client test. Start with read-only checks. Don't widen
permissions to make a diagnostic pass.

## Check the identity

- **SMB:** Confirm which account the client connected as. Reconnect with the
  intended account before drawing conclusions from a cached session. Check
  that the account has SMB access and belongs to the intended groups.
- **NFS:** Check the client's user and group IDs. `maproot` changes the
  identity for client root only. `mapall` makes requests use one identity.
  Check the user and group configured on the export. If you set a mapping
  group, you must also set its corresponding mapping user.
- **OpenTofu:** If the plan reports `Not authorized`, verify the key's account
  with the TrueNAS [`auth.me`](https://api.truenas.com/v25.10/api_methods_auth.me.html)
  call in an authenticated session using that key. Check the role required
  by the failed operation. Named mappings need `ACCOUNT_READ` through
  `provision_group_lookup` in this repository. Don't print the key or paste
  the full response into a shared log.

When comparing identifiers, distinguish numeric object IDs in the TrueNAS
API from the Unix user and group IDs used by filesystem ACLs.

## Check the share or export

1. Confirm that the service runs and that the share is enabled.
2. Compare the configured path with the path the client uses. Check that the
   dataset is mounted and unlocked.
3. For NFS, verify that the client is allowed by `hosts` or `networks`. Check
   whether the export is read-only before troubleshooting denied writes.
4. For SMB, inspect any share ACL as well as the filesystem ACL. A share ACL
   can block SMB access without affecting NFS access to the same files.

## Check the filesystem

Inspect the dataset root, each parent directory below it, and the file that
failed. A working mount doesn't prove the mapped identity can traverse a
nested directory. Look for an existing file that didn't inherit a newer ACL.

In TrueNAS, check the dataset owner, owning group, and ACL under
**Datasets > Permissions**. For a specific path, use these read-only sources
with an authorized account:

| Source | What to check |
| --- | --- |
| [`truenas_filesystem_acl`](https://github.com/truenas/terraform-provider-truenas/blob/v1.9.3/docs/data-sources/filesystem_acl.md) | Owner, owning group, ACL type, and entries. |
| [`truenas_filesystem_permissions`](https://github.com/truenas/terraform-provider-truenas/blob/v1.9.3/docs/data-sources/filesystem_permissions.md) | Owner and group IDs and the Unix permission bits for a POSIX path. |
| [`truenas_smb_share_acl`](https://github.com/truenas/terraform-provider-truenas/blob/v1.9.3/docs/data-sources/smb_share_acl.md) | SMB share permissions when the filesystem ACL doesn't explain an SMB refusal. |

Use these sources on demand. The storage root doesn't expose raw ACLs or
account details as persistent diagnostic outputs. If your account can't read
an object, ask an authorized administrator to inspect it. Don't grant the
storage key extra roles just to diagnose a failure.

## Verify from the client

With approval, use the actual client account to open a known file at the
failing path. If writes should work, create and remove a disposable test file.
If writes should fail, verify that the client can't create that test file.
Record the operation and result without credentials or raw account details.

For the model behind these checks, see [TrueNAS dataset and share access](../truenas-access.md).
For approved ACL changes, see [Set dataset permissions](truenas-dataset-permissions.md).
