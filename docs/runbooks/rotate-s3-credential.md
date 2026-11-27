# Rotate the S3 credential

Rotate the backend key pair after a suspected leak. Clients using the old keys
stop working until you update their credentials.

The pair authorizes access to bucket state files, not the workload APIs.
Workload roots use it for their S3 backend.

## Before you start

- `.env.tf` is writable, and the off-site recovery kit is at hand.
- Owner approval, because the apply rewrites a live credential.

## Steps

1. Lift the guard in `terraform/bootstrap/ovh/main.tf`: comment the
   `prevent_destroy` line of `ovh_cloud_project_user_s3_credential.state`,
   with the reason and the date. Commit it.

2. Replace the credential:

   ```sh
   task tf:ovh-bootstrap-apply -- \
     -replace=ovh_cloud_project_user_s3_credential.state -auto-approve
   ```

   Expect `1 to add, 0 to change, 1 to destroy`. The apply revokes the old
   pair and creates a new one.

3. Read the new pair:

   ```sh
   task tf:ovh-bootstrap-output -- -raw s3_access_key
   task tf:ovh-bootstrap-output -- -raw s3_secret_key
   ```

4. Update `.env.tf` and the off-site recovery kit with the new pair.

5. Restore the guard, and commit it. The rotation isn't finished until the
   guard is back.

## Next steps

- [Bootstrap the Terraform state backend](bootstrap-tf-backend.md) for the
  root the credential belongs to, and for the initial key read.
- [Terraform state design](../../terraform/BACKEND.md) for access controls and recovery.
- [OVH least privilege](../ovh-least-privilege.md) for account-key restrictions.
