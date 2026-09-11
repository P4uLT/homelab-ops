# Terraform state backend

This document records how the repository stores Terraform state. Read it
before the first `terraform init` against the state bucket.

The backend is an OVHcloud S3 bucket. One state file lives in one bucket
prefix per Terraform root (`key = <root-name>`). The bucket is not
Terraform-managed by the roots that use it. A separate, frozen bootstrap
root creates it once. This avoids the circular case where the backend
bucket stores the state of the root that creates it.

## Design

| Item | Decision |
|---|---|
| Provider | OVHcloud S3-compatible object storage |
| Layout | One bucket, one prefix per root (`key = <root-name>`) |
| Versioning | Enabled. Every state write keeps the previous version |
| Lifecycle | Noncurrent versions expire after 90 days |
| Encryption at rest (OVH) | SSE with AES256 |
| Encryption of the state payload | OpenTofu native encryption (AES-GCM, passphrase in `.env`) |
| Access | One dedicated project user with the `objectstore_operator` role, an allowlist policy, and no `DeleteBucket` or `DeleteObjectVersion` |

The two encryption layers are deliberate. SSE protects objects in the
bucket. OpenTofu native encryption protects the state payload itself, so
the encrypted state can also sit on the local disk and in backups
without exposing secrets.

## The bootstrap root

`terraform/bootstrap/` creates the whole access chain:

1. A dedicated project user with the `objectstore_operator` role.
   The role is required before an S3 policy can attach.
2. An S3 credential pair for that user.
3. An allowlist policy. It grants list, read, write, and version
   actions on the bucket. `DeleteBucket` is absent on purpose, and so is
   `DeleteObjectVersion`: the state writer must not be able to purge the
   versions that the recovery path relies on.
4. The bucket with versioning and SSE enabled.
5. The 90-day lifecycle rule for noncurrent versions.

The root uses a **local** backend. Its state is small and encrypted with
OpenTofu native encryption. This local state is acceptable because of
four guards:

- The root is frozen. It runs once and only again for drift checks.
  Every resource carries `prevent_destroy`, so a destroy must be a
  deliberate code change. This also applies to the S3 credential:
  rotation means lifting that guard in a reviewed commit.
- The bucket resource carries `prevent_destroy = true`.
- The encrypted state file is part of the off-site recovery kit.
- Worst case, the bucket is imported into a fresh bootstrap root. The
  import procedure below covers this.

Runs are idempotent. A second `apply` converges to the same result and
changes nothing. `plan` doubles as a drift check.

## Credential flow

| Credential | Source | Home |
|---|---|---|
| OVH API key triple | Minted once (`ovhcloud login` or the createToken page) | `.env`, git-ignored |
| Project ID, bucket name, region | OVHcloud account | `.env` |
| State encryption passphrase | Chosen once | `.env` and the recovery kit |
| S3 access and secret keys | Printed once by the bootstrap apply | `.env` and the recovery kit |

The S3 keys land in the bootstrap state too. This is why the state
encryption is enforced, not optional. The `.env` copies feed the main
roots, which read the S3 backend through environment variables. No
credential is ever written to a tracked file.

## Tasks

```sh
task tf:bootstrap-init     # once, downloads the OVH provider
task tf:bootstrap-plan     # preview; safe to repeat
task tf:bootstrap-apply    # create; idempotent
task tf:bootstrap-output   # read the S3 keys after the apply
task tf:bootstrap-state-list
task tf:fmt-check          # offline format check, part of task verify
task tf:validate           # schema check without a backend
```

The full procedure lives in `docs/runbooks/bootstrap-tf-backend.md`.

## Recovery

**State file recovery.** Pick the previous object version in the bucket
(or from the off-site copy) and restore it. Versioning keeps 90 days of
history.

**Bucket loss.** Re-run the bootstrap root against a new bucket name,
then re-apply every root with a fresh state, or import the old
resources. The roots are declarative, so convergence is expected.

**Bootstrap root loss.** Restore the encrypted state file from the
recovery kit, or start a fresh bootstrap root and import the bucket,
user, credential, and policy into it.

The recovery kit lives outside the repository. It holds: the age keys,
the state passphrase, the S3 keys, the OVH recovery codes, and the
restore test records.

## Off-site copies (planned)

The design adds two copies of the bucket, outside the repository scope
of this document's current phase:

1. An rclone mirror to RustFS.
2. An off-site copy on the Hetzner Storage Box, driven by the NAS.

A recurring restore test proves the chain. The test records stay with
the recovery kit.
