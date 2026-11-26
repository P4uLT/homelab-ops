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

1. Get owner approval before planning or contacting TrueNAS.
2. Verify the exact dataset path, its shares, and any other consumers in TrueNAS.
   Stop if the dataset contains files, snapshots, child datasets, or volumes.
   Back up the OpenTofu state before proceeding.
3. Change the dataset entry to the new preset and ACL. Set `protect = false`
   only for this dataset. Set `acltype = "nfsv4"` if the new ACL requires it.
4. Plan the replacement. Review the dataset, ACL, and any affected shares.
   Stop if the plan changes another dataset or an unrelated resource.
5. Get approval for the exact deletion. In TrueNAS, delete only the empty
   dataset with the administrator account. Don't select recursive deletion.
6. Set `protect = true` again and plan recreation. If refresh fails on the
   deleted dataset, follow [Recover a deleted dataset](#recover-a-deleted-dataset-from-the-state).
7. Confirm the new plan recreates only the intended resources, with no
   deletions or replacements. Apply after approval and check for drift.

The storage identity can't delete datasets. The provider also refuses
non-recursive deletion when snapshots, child datasets, or volumes exist.

## Recover a deleted dataset from the state

If a dataset disappears outside OpenTofu, refresh can fail with
`Missing Resource Identity After Read`.

1. Back up the state.
2. Remove only that entry with `tofu state rm`.
3. Plan again. The plan shows the resources to recreate.

## Next steps

- [Bootstrap TrueNAS](bootstrap-truenas.md) for the pool, identities, and
  access key.
- [Share a dataset over SMB and NFS](truenas-share-multiprotocol.md) to publish
  it again after recovery.
