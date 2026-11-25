# Recover TrueNAS storage

Use this page after a TrueNAS reinstall, a deleted dataset, or a failed
replacement.

## Adopt an existing pool

If `tank` survived a reinstall, import it in TrueNAS by its pool identifier.
OpenTofu adopts it at `truenas_pool.tank`, with `tank` as the import ID, only if
it's missing from the bootstrap state. These are separate operations.

Stop if the plan would create a pool on disks that still hold data. Restore
lost data from backup, not from the OpenTofu state.

## Recreate an empty dataset

The pinned provider replaces a dataset when its ACL type or share preset
changes. Replacing a dataset that holds data needs a migration, not an edit.
Use this procedure only when the dataset holds no data you need.

1. Change the dataset entry to the new preset and ACL, and set `protect = false`
   on that entry. Add `acltype = "nfsv4"` when the dataset reports
   `acltype = "inherit"`.
2. Delete the empty dataset in TrueNAS with the administrator account. Its ACL
   goes with it.
3. Plan the replacement. Confirm that it replaces only that dataset and its
   shares. Stop if it also replaces or changes other datasets.
4. Apply after approval, then set `protect = true` again.
5. Plan again and confirm that it reports no changes.

The replacement deletes the dataset and everything under it. Snapshots and child
datasets go with it.

The storage identity has no delete role, and TrueNAS doesn't scope one to a
single dataset. Keep the deletion with the administrator account.

## Recover a deleted dataset from the state

If the dataset disappears outside OpenTofu, a plan stops with
`Missing Resource Identity After Read`. The provider fails instead of dropping
the deleted dataset from the state.

1. Back up the state.
2. Remove only that entry with `tofu state rm`.
3. Plan again. The plan shows the resources to recreate.

## Next steps

- [Bootstrap TrueNAS](bootstrap-truenas.md) for the pool, identities, and
  access key.
- [Share a dataset over SMB and NFS](truenas-share-multiprotocol.md) to publish
  it again after recovery.
