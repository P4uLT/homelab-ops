# Store Home Assistant backups on TrueNAS

Use this page to send Home Assistant backups to a TrueNAS SMB share. Home
Assistant connects with its own service account. That account writes and
prunes backups, and reaches nothing else.

See the [TrueNAS access diagram](../truenas-access.md#follow-a-request-to-the-file)
for how the client account, share, and filesystem permissions fit together.

## Before you start

Check these conditions before you change the configuration:

- Home Assistant runs on Home Assistant OS. A container installation has no
  Supervisor and no **Storage** panel.
- The pool, the provisioning access, and the accounts exist. See
  [Bootstrap TrueNAS](bootstrap-truenas.md).
- These bootstrap flags are applied: `provision_smb_shares`,
  `provision_dataset_acls`, and `provision_group_lookup`, all `true`.
- The `ha-backup-writer` service account exists with an SMB password.
- The SMB service runs. A plan for an enabled share stops if the service is
  stopped.

## Declare the dataset

Add this entry to `datasets` in `terraform/truenas/gen8/gen8.local.auto.tfvars`:

```hcl
ha_backups = {
  name        = "tank/ha-backups"
  share_type  = "SMB"
  recordsize  = "1M"
  compression = "lz4"
  filesystem_acl = {
    preset = "nfs4_access"
    users  = { "ha-backup-writer" = "MODIFY" }
  }
  smb = {
    name      = "ha-backups"
    purpose   = "DEFAULT_SHARE"
    browsable = false
    ro        = false
  }
}
```

Backups are large archives written and read as a whole, so `recordsize` uses
`1M` and compression stays on the cheap `lz4` algorithm.

For an existing dataset, keep its current `share_type` and `acltype`.
Changing either can require replacement. See
[Recover TrueNAS storage](recover-truenas-storage.md) before that path.

1. Run `task tf:truenas-gen8-plan` and review the dataset, its ACL, and the
   share.
2. Run `task tf:truenas-gen8-apply` after approval.

## Connect Home Assistant

1. Open **Settings > System > Storage** in Home Assistant.
2. Select **Add storage**.
3. Fill the form:
   - **Name**: `truenas_backups`. Letters, numbers, and underscores only.
   - **Usage**: **Backup**.
   - **Type**: **Samba/Windows (CIFS)**.
   - **Server**: the NAS hostname or address.
   - **Remote share**: `ha-backups`.
   - **Username** and **Password**: `ha-backup-writer` and its password.
4. Select **Connect**.

If the connection fails, Home Assistant shows a **Samba/Windows (CIFS)
version** option. Keep **Auto (2.1+)** unless the NAS forces an older version.
Older versions are less secure.

The first storage added with the **Backup** usage becomes the default local
backup location. Backups without their own location go there, including the
ones Home Assistant creates before updates.

## Test the backup

1. Open **Settings > System > Backups** and create a backup. Choose the
   `truenas_backups` location if it isn't the default.
2. Confirm the archive appears in `tank/ha-backups` on TrueNAS.
3. Delete the backup from the **Backups** page. Confirm the file leaves the
   dataset. This proves the prune right.
4. Manage retention from Home Assistant's backup settings if you use
   automatic backups.

## Known limits

- `ha-backup-writer` can change only this dataset. It holds no other grants.
- Don't reuse the account on another share. Its writes are tracked together.

If the connection fails, see
[Diagnose TrueNAS share access](diagnose-truenas-share-access.md).

## Next steps

- [Share over SMB](truenas-share-smb.md) for a person-facing share.
