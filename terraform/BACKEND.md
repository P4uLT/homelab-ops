# Terraform state backend

Read before the first `tofu init` against the state bucket.
The tool is OpenTofu (`tofu`). "Terraform" refers to the infrastructure layer.

Each root stores state under a separate prefix in an OVHcloud S3 bucket.
A frozen bootstrap root creates the bucket using local state, avoiding a
backend that depends on itself.

## Design

| Item | Decision |
| --- | --- |
| Provider | OVHcloud S3-compatible object storage |
| Layout | One bucket, one state key per root: `<path>/terraform.tfstate`, mirroring the root path |
| Versioning | Enabled. Every state write keeps the previous version |
| Lifecycle | Noncurrent versions expire after 90 days |
| Encryption at rest (OVH) | SSE with AES256 |
| Encryption of the state payload | OpenTofu native encryption (AES-GCM, passphrase in `.env.tf`) |
| Access | One dedicated project user with the `objectstore_operator` role, an allowlist policy, and no `DeleteBucket` or `DeleteObjectVersion` |

SSE protects bucket objects. Native encryption also protects downloaded state
and backups, using the passphrase in `.env.tf`.

## The bootstrap root

`terraform/bootstrap/ovh/` creates the whole access chain:

1. A dedicated project user with the `objectstore_operator` role.
   OVHcloud requires the role before an S3 policy can attach.
2. An S3 credential pair for that user.
3. An allowlist policy. It grants list, read, write, and version
   actions on the bucket. `DeleteBucket` is absent on purpose, and so
   is `DeleteObjectVersion`: the state writer must not be able to purge
   the versions that the recovery path relies on.
4. The bucket, in a 3-AZ region, with versioning and SSE enabled.
5. The 90-day lifecycle rule for noncurrent versions.

The local backend uses native state encryption. Protect it with these controls:

- Restrict the frozen root to initial setup and drift checks.
- Set `prevent_destroy = true` on every resource, including the bucket and S3 credential.
  Credential rotation requires lifting the guard in a reviewed commit. Follow
  [Rotate the S3 credential](../docs/runbooks/rotate-s3-credential.md).
- Include the encrypted local state in the off-site recovery kit.
- If state is lost, import existing resources as described under [Recovery](#recovery).

Use `plan` for drift checks. With unchanged inputs, the expected apply result is `No changes`.

## Root layout rules

Separate roots by provider and operational scope. Resources with different
apply cadences need separate states. Don't split solely by resource type or
include unrelated resources through dependency graphs.

| Root | Covers | Cadence |
| --- | --- | --- |
| `bootstrap/ovh/` | the state bucket, its user, and its policy | once |
| `bootstrap/pve/jarvis/` | the Terraform access chain on jarvis: role, group, user, ACL, API token | once |
| `proxmox/jarvis/` | the PVE server jarvis | often |
| `bootstrap/truenas/gen8/` | the Gen8 data pool, provisioning identity, and file services | rarely |
| `truenas/gen8/` | the Gen8 datasets and shares | sometimes |
| `dns/` (planned) | public DNS zone | sometimes |
| `ovh-project/` (planned) | account-level users | rare |

A new PVE server gets its own root, named after the server, with its
own state key, and its own access root under `bootstrap/pve/`.

Keep `bootstrap/ovh/` restricted to the state backend and its bucket-scoped user.
Place DNS zones, account-level users, and application buckets in sibling roots.
Those resources need independent changes and access policies.

Every root declares its backend key in its own `backend.tf`. The key
mirrors the root path under `terraform/` plus `terraform.tfstate`: the
`proxmox/jarvis` root stores at `proxmox/jarvis/terraform.tfstate`.
Terragrunt can generate this layout with `${path_relative_to_include()}`.
Adopting that layout avoids migration only if each effective backend location stays unchanged.
Changing the bucket, key, or workspace can select a different state.

The tasks pass `terraform/backend.s3.ovh.hcl` to each `init` as partial
configuration for the OVH region, endpoint, validation skips, and lockfile.
This tracked file contains no secrets. Keys are per-root, while the bucket
name is read from `.env.tf`. See [object storage conventions](../docs/object-storage.md)
for bucket policy.

The [directory layout](README.md#layout) groups roots by provider with shared
modules. Tasks use the explicit `TF_ROOTS` list, excluding modules from root validation.

## State locations and code moves

Directory paths and backend locations are independent.
Follow [Move Terraform code or state](../docs/runbooks/move-tf-state.md) for
code-only moves and approved backend migrations.

## Region choice, and no replica

The 3-AZ region protects against one availability-zone failure, not region loss.
Version history is in the same bucket. There is no cross-region replica.

| Failure | Control |
| --- | --- |
| Disk, rack, or availability zone loss | The 3-AZ region |
| Bad apply, or an overwritten state | The 90-day version history |
| Bucket or region loss | The off-site copies below |
| OVHcloud account loss | The off-site copies below |

Off-site copies also cover OVHcloud account loss, which an OVHcloud replica
wouldn't cover. A replica would require another bucket, lifecycle policy, and
restricted writer scope to avoid divergent states.

## Credential flow

Repository-level dotenv files provide shared credentials to Task.
Root-specific connection secrets use git-ignored `*.local.auto.tfvars` beside their consumer.

| Credential | Source | Home |
| --- | --- | --- |
| OVH API key triple | Minted once (`ovhcloud login` or the createToken page) | `.env.account.ovh.tf`, git-ignored |
| Project ID | OVHcloud account | `.env.account.ovh.tf` (`OVH_CLOUD_PROJECT_SERVICE`) |
| State encryption passphrase | Chosen once | `.env.tf` (`TF_VAR_state_passphrase`) and the recovery kit |
| S3 access and secret keys | Printed once by the bootstrap apply | `.env.tf` (`AWS_*`) and the recovery kit |
| Bucket name | Chosen once | `.env.tf` (`TF_VAR_bucket_name`) |
| Bucket region | Chosen once | The root's `ovh.local.auto.tfvars`, git-ignored |
| PVE access-management API token, per node | Issued outside OpenTofu | `bootstrap/pve/<node>/<node>.local.auto.tfvars`, git-ignored |
| PVE workload API token, per node | Minted by the access root | `proxmox/<node>/<node>.local.auto.tfvars`, git-ignored |

S3 keys also appear in the encrypted bootstrap state.
Other roots use the copies in `.env.tf` through native `AWS_*` variables.
Keep credential values out of tracked files.

## Tasks

```sh
task tf:init               # initialize every root; downloads the provider
task tf:bootstrap-plan     # preview; safe to repeat
task tf:bootstrap-apply    # create; idempotent
task tf:bootstrap-output   # read the S3 keys after the apply
task tf:bootstrap-state-list
task tf:jarvis-plan        # preview the PVE workload; reads the node
task tf:jarvis-apply       # change the node; owner approval
task tf:fmt-check          # offline format check, part of task verify
task tf:validate           # init, then schema-check every root
```

Follow [Bootstrap the state backend](../docs/runbooks/bootstrap-tf-backend.md)
or [Provision an LXC workload](../docs/runbooks/provision-pve-ct.md).

## Recovery

Follow [Recover Terraform state](../docs/runbooks/recover-tf-state.md) to restore
a state file or recover from bucket or bootstrap-root loss.

Store the recovery kit outside the repository with:

- Encrypted bootstrap state and available root-state copies, including decryption settings.
- Age keys, state passphrase, S3 credentials, and OVH recovery codes.
- Restore test records.

## Off-site copies (planned)

Planned copies outside this repository's implemented scope:

1. An rclone mirror to RustFS.
2. An off-site copy on the Hetzner Storage Box, driven by the NAS.

Test restoration regularly and store the results with the recovery kit.
