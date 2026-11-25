# Bootstrap TrueNAS on the Gen8

Use this runbook for a fresh TrueNAS Community Edition 25.10 installation.
OpenTofu manages storage and access, not the TrueNAS installation or its
initial network access. The roots use the
[official TrueNAS provider](https://github.com/truenas/terraform-provider-truenas/tree/v1.9.3).

## Prepare access and disks

Get owner approval before contacting TrueNAS, including a plan. Confirm the
management endpoint and trust its TLS certificate. For a private CA, set
`truenas_ca_cert` to the local certificate file in `PEM` format. Don't disable
certificate verification.

1. Create a bootstrap API key for the initial TrueNAS administrator.
2. Check the four WD Red serial numbers against the TrueNAS disk inventory.
   Exclude the boot disk. Creating a pool erases the selected disks.
3. Copy the example in `terraform/bootstrap/truenas/gen8/` to
   `gen8.local.auto.tfvars` in that root. Restrict the file to its owner.
   Set `truenas_host` to the management hostname or address, without a scheme
   or path. Enter the bootstrap key in `truenas_api_key` and the four serials.
4. Configure the [state backend](../../terraform/BACKEND.md), then run
   `task tf:init`. The roots store separate encrypted states in S3.

## Create the pool and provisioning account

```sh
task tf:truenas-gen8-bootstrap-plan
```

Review the plan before running apply. Apply presents a fresh plan. For a new
NAS, expect the `tank` RAIDZ2 pool, provisioning group, user, privilege, and
service API key. Also expect the NFS and `cifs` services. The `cifs` service
handles Server Message Block shares. This step doesn't create a share or
grant file access to `terraform-prov`. Stop if the plan deletes or replaces
anything.
`prevent_destroy` protects the pool while the resource stays in configuration.
Don't remove the resource block as a way to bypass that check.

After approval, run `task tf:truenas-gen8-bootstrap-apply`. Review the fresh
plan before confirming.

If you already applied the bootstrap without the API key resource, expect
only `truenas_api_key.provisioner` to be added. Stop if the plan changes the
pool. If you issued a separate service key by hand, revoke it only after
validating the new one.

The provider stores the generated `terraform-prov` key in encrypted bootstrap
state. The `api_key_value` output is sensitive, but `-raw` prints the key.
Retrieve it only in a private terminal, not in a recorded session or CI log:

```sh
task tf:truenas-gen8-bootstrap-output -- -raw api_key_value
```

Copy the example in `terraform/truenas/gen8/` to `gen8.local.auto.tfvars` in
that root. Restrict the file to its owner. Enter the service key, not the
admin key, and list only the Proxmox VE clients that need the share.

The bootstrap `services` object uses the native names `nfs` and `cifs`.
Set a value to `false` to stop the service and disable it at boot without
removing its shares. Both services default to `true` on the Gen8.

## Publish the `iso` share

```sh
task tf:truenas-gen8-plan
```

For a new NAS, expect `tank/iso` and its read-only NFS export. Replace the
example host with a client hostname that TrueNAS can resolve. For a subnet,
use `networks` instead of `hosts` and include the prefix length.
The role list is based on the documented dataset and NFS API permissions.
It isn't restricted to `tank/iso` by TrueNAS. If the provider reports a
permission error, identify the failing method before granting another role.
Don't switch this root to the admin key.

After approval, run `task tf:truenas-gen8-apply`. Review the fresh plan
before confirming.

As a TrueNAS operator, place an image in `template/iso/` under the dataset
through an authorized write path. Proxmox can't upload to this read-only
export. In Proxmox, register the NFS storage with type `iso` only and check
that the image appears. Run the provisioning plan again and check for no
changes. After validating service access, revoke the bootstrap key and remove
its local copy. Issue a fresh admin key if the bootstrap root needs maintenance.

## Add Windows access to the image library

1. In the bootstrap tfvars, set `provision_smb_shares = true`. Add the
   example group and user. Set `user_passwords` using the user's map key.
   Keep the local file readable only by its owner.
2. If OpenTofu will manage the dataset permissions, configure the bootstrap
   roles in [Manage dataset permissions](#manage-dataset-permissions).
3. Plan the bootstrap changes. Expect the new identities and any role
   changes you enabled. Stop if the plan changes the pool or replaces the
   provisioning key. Apply only after approval.
4. Review the permissions on `tank/iso`. Add the example `smb` block to
   `datasets.iso` in the storage tfvars. Leave the NFS export unchanged.
   Keep `smb.ro = true` until you want uploads and have checked access.
   Plan and review the share and permission changes before applying.
5. In Windows Explorer, open `\\<nas-address>\iso` with the file user.
   Use the NAS address, not the web reverse proxy.

For uploads, set `smb.ro = false` and grant the publishing group write
access on the dataset. The share setting alone doesn't grant file access.
Create `template/iso/` from Windows if it doesn't exist. Create and remove
a test file there, then check that an uploaded image appears in Proxmox.

To rotate a password, change the local secret and increment the user's
`password_wo_version`. Changing `full_name` doesn't change the login.
Changing `username` forces account replacement with the pinned provider.
To preserve access during a login change, create the new account in the same
group. Test it before removing the old account in a separate reviewed apply.
Keep map keys stable for existing accounts and groups.

## Add datasets and shares

Add an entry to `datasets` in the provisioning root's local tfvars. Keep
its map key stable: changing it changes the resource address. The module
creates a filesystem dataset and uses its reported mountpoint for any
requested shares. Omit `nfs` and `smb` for storage used only by a local app.
Set a share's `enabled` to `false` to disable it without deleting it. An NFS
share needs explicit hosts or networks.

For a new Server Message Block share, first set `provision_smb_shares = true`
in the bootstrap root and apply the reviewed role change. This grants API
permissions, not file access. Then declare the share under `smb` in the
provisioning root. The nested `smb.options` settings require TrueNAS 26.0 or
later. Use the top-level settings on 25.10.

### Manage dataset permissions

To manage permissions from OpenTofu, opt in with `provision_dataset_acls`
in the bootstrap tfvars. This grants filesystem attribute read and write
roles to the storage identity. TrueNAS doesn't scope these roles to one
dataset. The storage identity still can't manage users or groups.

For an image library with a publishing group, use
`filesystem_acl.preset = "posix_group_rw_others_ro"` and set `group_gid` to
the group's numeric ID. For one group by name, use `group_name`. For several,
use `group_names`. Use only one of these settings. For either name-based
setting, enable `provision_group_lookup` in the bootstrap tfvars. This grants
account and group read access through `ACCOUNT_READ`, not write access.
Apply the approved bootstrap role changes before planning storage.
The module resolves the names and sends only numeric IDs to the ACL.
The preset grants the owner and each selected group write access. Others
keep read and traverse access. The preset sets default entries for new
children and requires a dataset with a `POSIX1E` ACL.

For a custom ACL, set `filesystem_acl.type` to match the dataset:
`POSIX1E` or `NFS4`. Declare the full ACL in `filesystem_acl.entries`.
Use `id` with the numeric group ID. Resolving `who` at refresh requires
`ACCOUNT_READ`, which the storage identity doesn't have by default. The module encodes
the entries for the provider. See `datasets.iso` in the provisioning example.
Review the current permissions first. The resource replaces the full list
on that path without changing existing child files or directories. Don't
bypass deletion protection to stop managing an ACL: the provider removes
extended ACL entries when it destroys the resource. To keep the ACL without
managing it, back up the state and use a reviewed state-only removal.

For new datasets accessed over both protocols, use `share_type = "MULTIPROTOCOL"`
and `smb.purpose = "MULTIPROTOCOL_SHARE"`. See the
[TrueNAS multiprotocol guide](https://www.truenas.com/docs/scale/25.10/scaletutorials/shares/mixedmodeshares/).
Don't set a new preset or ACL type on an existing dataset to match this
example. OpenTofu can plan to replace it.

TrueNAS can require a full administrator to convert an existing Legacy Share
to a Multi-Protocol Share. If the update fails on `auxsmbconf`, make the
approved preset change in TrueNAS. Then run a storage plan to check for
drift. Don't elevate the provisioning key for this conversion.

### Set capacity and encryption

Set quota and reservation values in bytes. Supply any dataset key or
passphrase in `dataset_encryption_secrets`, keyed by the dataset's map key.
These inputs are local, ephemeral, and passed to write-only attributes.
Store a recovery copy outside the NAS before creating an encrypted dataset.
Review create-only settings such as the encryption mode before apply.
The module rejects replacements that would destroy the dataset while its
resource remains configured.

## Recover an existing pool

If `tank` survived a TrueNAS reinstall, import it in TrueNAS by its pool identifier. OpenTofu
adopts it at `truenas_pool.tank`, with `tank` as the
import ID, only if it's missing from the bootstrap state. These are separate operations. Stop if the
plan would create a pool on disks that still hold data. Restore lost data from
backup, not from the OpenTofu state.

The mocked tests in `task tf:test-truenas` don't qualify live permissions,
disk discovery, or client access. Verify those on the target system.
