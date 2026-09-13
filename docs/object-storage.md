# OVH object storage conventions

Rules for every bucket in the OVH project, state bucket included.

## Buckets

One bucket per data class, named `homelab-ops-<class>`. The bucket is
the access boundary: one project user with an allowlist policy per
bucket, never one user across classes. Sources inside a class separate
by key prefix, for example `vm/`, `lxc/`, `docker/`, `k8s/` under
backups.

| Class | Bucket | Status |
| --- | --- | --- |
| Terraform state | `tfstate` | live, see `terraform/BACKEND.md` |
| Workload backups | `backups` | planned |

## Per-bucket rules

- SSE on. Non-state payloads are encrypted client-side before upload.
- Region defaults to `eu-west-par` (3-AZ). A cheaper 1-AZ region is
  allowed for bulk data; the reason is written in the root that owns
  the bucket.
- Versioning and lifecycle follow the class. The state bucket keeps 90
  days of noncurrent versions; a backup class decides at creation.
- A new bucket gets its own sibling Terraform root, never
  `bootstrap/ovh`.

OVH bills stored GiB-hours, egress, and request classes — not buckets.
