# OVH object storage conventions

Bucket policy for the OVH project, including Terraform state.
See [OVH least privilege](ovh-least-privilege.md) for credentials.

## Bucket naming and access

Use one `homelab-ops-<class>` bucket and one allowlisted project user per data
class. Don't share users across classes. Separate sources by key prefix,
such as `vm/`, `lxc/`, `docker/`, and `k8s/` under backups.

| Class | Bucket | Status |
| --- | --- | --- |
| Terraform state | `tfstate` | live, see [Terraform state design](../terraform/BACKEND.md) |
| Workload backups | `backups` | not created yet |

## Per-bucket rules

- SSE on. Encrypt non-state payloads client-side before upload.
- Region defaults to `eu-west-par` (3-AZ). Bulk data may use a cheaper 1-AZ
  region if the creating root records the reason.
- Versioning and lifecycle follow the class. The state bucket keeps 90 days
  of noncurrent versions. A backup class decides at creation.
- A new bucket gets its own sibling Terraform root, never `bootstrap/ovh`.

OVH bills stored GiB-hours, egress, and request classes, not buckets.

## Related

- [Terraform state design](../terraform/BACKEND.md): the state bucket in
  context.
- [Bootstrap the Terraform state backend](runbooks/bootstrap-tf-backend.md):
  the one-time bucket creation.
- [OVH least privilege](ovh-least-privilege.md): bucket credentials.
