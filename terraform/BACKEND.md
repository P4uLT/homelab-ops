# Terraform state backend

This document records how the repository stores Terraform state. Read it
before the first `tofu init` against the state bucket. The tool is
OpenTofu (`tofu`). "Terraform" here names the IaC layer and its
conventions.

The backend is an OVHcloud S3 bucket. One state file lives in one bucket
prefix per Terraform root (`key = <root-name>`). The bucket isn't
Terraform-managed by the roots that use it. A separate, frozen bootstrap
root creates it once. This avoids the circular case where the backend
bucket stores the state of the root that creates it.

The bucket lives in a 3-AZ region. That survives the loss of one
availability zone, not the loss of the whole region. See Region choice
below.

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

The two encryption layers are deliberate. SSE protects objects in the
bucket. OpenTofu native encryption protects the state payload itself, so
the encrypted state can also sit on the local disk and in backups
without exposing secrets.

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

The root uses a **local** backend. Its state is small and encrypted with
OpenTofu native encryption. This local state is acceptable because of
four guards:

- The root is frozen. It runs once and only again for drift checks.
  Every resource carries `prevent_destroy`, so a destroy must be a
  deliberate code change. This also applies to the S3 credential:
  rotation means lifting that guard in a reviewed commit. The procedure
  is in the bootstrap runbook.
- The bucket resource carries `prevent_destroy = true`.
- The encrypted state file is part of the off-site recovery kit.
- Worst case, you import the bucket into a fresh bootstrap root. The
  import procedure below covers this.

Runs are idempotent. A second `apply` converges to the same result and
changes nothing. `plan` doubles as a drift check.

## Root layout rules

One root covers one triplet: provider, blast radius, and apply cadence.
Don't split roots by resource type. Two resources with different
cadences never share a state. A plan must not touch unrelated resources
through the graph.

| Root | Covers | Cadence |
| --- | --- | --- |
| `bootstrap/ovh/` | the state bucket, its user, and its policy | once |
| `bootstrap/pve/jarvis/` | the Terraform access chain on jarvis: role, group, user, ACL, API token | once |
| `proxmox/jarvis/` | the PVE server jarvis | often |
| `truenas/` (planned) | NAS import | sometimes |
| `dns/` (planned) | public DNS zone | sometimes |
| `ovh-project/` (planned) | account-level users | rare |

A new PVE server gets its own root, named after the server, with its
own state key, and its own access root under `bootstrap/pve/`.

`bootstrap/ovh/` stays frozen and narrow. Its guards (`prevent_destroy`, the
local backend, the run-once contract) hold only while its scope is the
state backend. A mutable resource conflicts with `prevent_destroy`: it
needs regular change, but the root forbids destruction. DNS zones,
account-level users, and application buckets get sibling roots. Never
add them here. The bootstrap policy limits its user to the state
bucket. A user for another purpose belongs to another root.

Every root declares its backend key in its own `backend.tf`. The key
mirrors the root path under `terraform/` plus `terraform.tfstate`: the
`proxmox/jarvis` root stores at `proxmox/jarvis/terraform.tfstate`.
Terragrunt can generate this layout with `${path_relative_to_include()}`.
Adopting that layout avoids migration only if each effective backend location stays unchanged.
Changing the bucket, key, or workspace can select a different state.

The OVH S3 dialect facts (region, endpoint, validation skips, lockfile)
live once, in `terraform/backend.s3.ovh.hcl`. The tf tasks pass the
file to every `init` as a partial config. The file holds nothing
secret, and it stays tracked: the state location stays readable. Only
the key stays per root, and the bucket name keeps its env-only path
through `.env.tf`. Bucket-level conventions (classes, users, regions)
live in `docs/object-storage.md`.

The tree groups by provider category: `proxmox/`, and later `truenas/`
or `dns/`. A category holds one root per target, plus its own
`modules/` for what its roots share. `bootstrap/` is the category of
frozen roots that mint credentials: the state backend (`ovh/`) and
each PVE node's Terraform access chain (`pve/<node>/`). Root discovery is the explicit `TF_ROOTS` list in the
tf tasks, so validation never treats a module as a root.

## State locations and code moves

`git mv` moves code, not remote state.
For a code-only move, keep the existing backend key.
Update relative module paths, partial backend paths, and the task root list.
The key can differ from the directory until a separate migration is approved.

Before changing a backend location, pause writers and preserve the source state.
Preserve any destination state too. Keep the decryption passphrase and encryption configuration available.
Retain the old backend metadata for an owner-approved `tofu init -migrate-state` operation.
Supply the correct partial backend configuration for the destination.
Verify the copied state and review a plan before applying infrastructure changes.
Don't let two roots manage the same resources.

`-reconfigure` selects a backend without copying state. It isn't a migration shortcut.
`-force-copy` accepts migration prompts automatically. Don't use it to bypass destination-state review.
Resource `moved` blocks change addresses inside a state, not its bucket or object key.

## Region choice, and no replica

The bucket lives in a 3-AZ region. That survives the loss of one
availability zone. It doesn't survive the loss of the whole region,
and the 90-day version history lives in the same bucket.

There is no cross-region replica. Each failure has a designated
control:

| Failure | Control |
| --- | --- |
| Disk, rack, or availability zone loss | The 3-AZ region |
| Bad apply, or an overwritten state | The 90-day version history |
| Bucket or region loss | The off-site copies below |
| OVHcloud account loss | The off-site copies below |

A replica inside OVHcloud would cover a region loss only, and never the
loss of the account. The off-site copies cover both. A replica would
add a second copy under the same provider for little gain. It costs a
second bucket, a second lifecycle rule, and a writer scope. That scope
must stay narrow, or the two states diverge.

## Credential flow

Each secret lives where its consumer resolves it. The Task-resolved
dotenv files stay at the repository root. A root's own connection
secrets live in the root, as a git-ignored `*.local.auto.tfvars`.

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

The S3 keys land in the bootstrap state too. This is why `backend.tf`
enforces the state encryption. The `.env.tf` copies feed the main
roots, which read the S3 backend through its native `AWS_*` variable
names. No credential is ever written to a tracked file.

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

The bootstrap procedure lives in
`docs/runbooks/bootstrap-tf-backend.md`. The workload procedure lives
in `docs/runbooks/provision-pve-ct.md`.

## Recovery

**State file recovery.** Pause plans and applies for the affected root.
Preserve the state before restoring a bucket version or an encrypted backup.
Restore only with owner approval and the matching decryption settings.
Review the resource addresses, including migrations that followed the snapshot.
Inspect a plan and stop on unexpected creation, replacement, or deletion.
Restoring state doesn't roll back infrastructure or application data.
Noncurrent bucket versions expire after 90 days.

**Bucket loss.** Recover the bootstrap state before reviewing a replacement bucket and its access policy.
Restore each root's encrypted state to its intended backend location before resuming plans.
Without a usable state copy, import existing resources through a reviewed recovery plan.
Don't apply an empty state to existing infrastructure. It can create duplicate resources or fail on existing objects.
Off-site copies are planned below, so bucket-loss recovery isn't qualified here.

**Bootstrap root loss.** Restore its encrypted local state from the recovery kit.
If that copy is unavailable, import the existing access resources rather than recreating the chain.
Imports don't recover secrets returned only at credential creation.
Use the saved credentials or review a separate rotation.

The recovery kit lives outside the repository.
Recovery needs the encrypted bootstrap state, available root-state copies, age keys, state passphrase,
S3 keys, OVH recovery codes, and restore test records.
Keep the decryption settings with each encrypted state copy.

## Off-site copies (planned)

The design adds two copies of the bucket, outside the repository scope
of this document's current phase:

1. An rclone mirror to RustFS.
2. An off-site copy on the Hetzner Storage Box, driven by the NAS.

A recurring restore test proves the chain. The test records stay with
the recovery kit.
