# Rotate the S3 credential

Rotate the state-backend key pair when it may have leaked. One apply revokes
the old pair and mints a new one. Anything that already authenticates with
the old keys stops working until you re-point it.

No workload root authenticates with the pair. The exposure is limited to the
state files in the bucket.

## Before you start

- `.env.tf` is writable, and the off-site recovery kit is at hand.
- Owner approval, because the apply rewrites a live credential.

## Steps

1. Lift the guard in `terraform/bootstrap/ovh/main.tf`: comment the
   `prevent_destroy` line of `ovh_cloud_project_user_s3_credential.state`,
   with the reason and the date. Commit it.

2. Replace the credential:

   ```sh
   task tf:bootstrap-apply -- \
     -replace=ovh_cloud_project_user_s3_credential.state -auto-approve
   ```

   Expect `1 to add, 0 to change, 1 to destroy`. The apply revokes the old
   pair and mints a new one.

3. Read the new pair:

   ```sh
   task tf:bootstrap-output -- -raw s3_access_key
   task tf:bootstrap-output -- -raw s3_secret_key
   ```

4. Update `.env.tf` and the off-site recovery kit with the new pair.

5. Restore the guard, and commit it. The rotation is not finished until the
   guard is back.

## Next steps

- [Bootstrap the Terraform state backend](bootstrap-tf-backend.md) for the
  root the credential belongs to, and for the initial key read.
- [Terraform state design](../../terraform/BACKEND.md) for the four guards,
  the import path, and what the key can reach.
- [OVH least privilege](../ovh-least-privilege.md) when the broad account key
  is the real problem, not the S3 pair.
