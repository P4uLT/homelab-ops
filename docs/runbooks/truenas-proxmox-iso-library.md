# Serve a TrueNAS ISO library to Proxmox

Use this page to store Proxmox ISO images on a TrueNAS SMB share. Proxmox VE
connects through its native CIFS storage backend. No NFS export is needed.

See the [TrueNAS access diagram](../truenas-access.md#follow-a-request-to-the-file)
for how the client account, share, and filesystem permissions fit together.

## Before you start

Check these conditions before you change the configuration:

- The pool, the provisioning access, and the accounts exist. See
  [Bootstrap TrueNAS](bootstrap-truenas.md).
- These bootstrap flags are applied: `provision_smb_shares`,
  `provision_dataset_acls`, and `provision_group_lookup`, all `true`.
- The `iso-publishers` group holds the people who publish images. The
  `pve-iso-reader` service account exists with an SMB password.
- The SMB service runs. A plan for an enabled share stops if the service is
  stopped.

## Decide who publishes

Grant `MODIFY` to the publishers and `READ` to `pve-iso-reader`.

With `READ`, Proxmox lists and opens images, but an upload from the Proxmox
interface fails. Publish from Windows or another SMB client instead, and keep
the storage account read-only. Grant `MODIFY` to the storage account only if
uploads must run from the Proxmox interface.

## Declare the dataset

Add this entry to `datasets` in `terraform/truenas/gen8/gen8.local.auto.tfvars`:

```hcl
iso = {
  name        = "tank/iso"
  share_type  = "SMB"
  recordsize  = "1M"
  compression = "lz4"
  filesystem_acl = {
    preset = "nfs4_access"
    groups = { "iso-publishers" = "MODIFY" }
    users  = { "pve-iso-reader" = "READ" }
  }
  smb = {
    name      = "iso"
    purpose   = "DEFAULT_SHARE"
    browsable = true
    ro        = false
  }
}
```

The share stays writable because the publishers write through it. The ACL,
not the share, limits the reader account.

For an existing dataset, keep its current `share_type` and `acltype`.
Changing either can require replacement. See
[Recover TrueNAS storage](recover-truenas-storage.md) before that path.

Proxmox lists ISO images under `template/iso/` in the share. Create that
path as a publisher before you connect the storage. `pve-iso-reader` has no
right to create it.

1. Run `task tf:truenas-gen8-plan` and review the dataset, its ACL, and the
   share.
2. Run `task tf:truenas-gen8-apply` after approval.

## Register the storage in Proxmox

1. In Proxmox, open **Datacenter > Storage > Add** and select **SMB**.
2. Enter an ID, the NAS address in **Server**, and `iso` in **Share**. Prefer
   an IP address unless your DNS is reliable.
3. Enter `pve-iso-reader` and its password. Proxmox stores the password in
   `/etc/pve/priv/storage/STORAGE_ID.pw`, readable by root only.
4. Set **Content** to **ISO image** only.
5. Select **Add**.

From a Proxmox shell, the same registration:

```sh
pvesm scan cifs NAS_HOST --username pve-iso-reader
pvesm add cifs truenas-iso --server NAS_HOST --share iso \
  --content iso --username pve-iso-reader
```

`pvesm add` prompts for the password.

## Test the access

1. Copy a test ISO into `template/iso/` as a publisher, over SMB.
2. Run `pvesm list truenas-iso --content iso` and confirm the file appears.
3. Create or edit a VM and select the test image from the `truenas-iso`
   storage.
4. Try an upload from the Proxmox interface. With `READ`, it must fail.
5. Remove the test image as a publisher.

If listing or opening fails, see
[Diagnose TrueNAS share access](diagnose-truenas-share-access.md).

## Known limits

- CIFS storage doesn't support storage-level snapshots.
- The reader account can reach only this dataset. It holds no other grants.

## Next steps

- [Share over SMB](truenas-share-smb.md) for a person-facing share.
- [Share over SMB and NFS](truenas-share-multiprotocol.md) if a client needs
  Unix identity semantics.
