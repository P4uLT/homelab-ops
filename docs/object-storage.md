# OVH object storage conventions

Rules for every bucket in the OVH project, state bucket included. The
Terraform roots that create them follow these rules. The credential side is in
[OVH least privilege](ovh-least-privilege.md).

## Bucket naming and access

One bucket per data class, named `homelab-ops-<class>`. The bucket is the
access boundary: one project user with an allowlist policy per bucket, never
one user across classes. Sources inside a class separate by key prefix, for
example `vm/`, `lxc/`, `docker/`, `k8s/` under backups.

| Class | Bucket | Status |
| --- | --- | --- |
| Terraform state | `tfstate` | live, see [Terraform state design](../terraform/BACKEND.md) |
| Workload backups | `backups` | not created yet |

## Per-bucket rules

Every bucket follows the same four rules:

- SSE on. Encrypt non-state payloads client-side before upload.
- Region defaults to `eu-west-par` (3-AZ). Bulk data may use a cheaper 1-AZ
  region. The root that owns the bucket records the reason.
- Versioning and lifecycle follow the class. The state bucket keeps 90 days
  of noncurrent versions. A backup class decides at creation.
- A new bucket gets its own sibling Terraform root, never `bootstrap/ovh`.

OVH bills stored GiB-hours, egress, and request classes, not buckets.

## Related

- [Terraform state design](../terraform/BACKEND.md): the state bucket in
  context.
- [Bootstrap the Terraform state backend](runbooks/bootstrap-tf-backend.md):
  the one-time bucket creation.
- [OVH least privilege](ovh-least-privilege.md): the keys that reach these
  buckets.
