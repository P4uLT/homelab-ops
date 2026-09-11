# Bootstrap the Terraform state backend

One-time procedure. It creates the OVH S3 bucket that stores Terraform
state, plus its access chain. The design lives in
`terraform/BACKEND.md`. Re-running any step is safe; everything
converges.

## Prerequisites

- The `OVH_*` and `TF_STATE_PASSPHRASE` values from `.env.example`,
  filled into your local `.env` file.
- Owner approval, because this creates billable resources.

## Steps

1. Mint the OVH API credentials and fill them into `.env`:
   `mise exec -- ovhcloud login`, then copy the key triple from
   `ovhcloud config show` into `OVH_APPLICATION_KEY`,
   `OVH_APPLICATION_SECRET`, and `OVH_CONSUMER_KEY`.
2. Choose the bucket name and region. Fill `OVH_BUCKET` and
   `OVH_REGION` in `.env`. Keep the name out of any tracked file.
3. Download the provider: `task tf:bootstrap-init`.
4. Preview: `task tf:bootstrap-plan`. Expect five resources to add.
5. Create: `task tf:bootstrap-apply`.
6. The apply prints the S3 access key and secret key once. Copy them
   into `.env` (`OVH_S3_ACCESS_KEY`, `OVH_S3_SECRET_KEY`) and into the
   off-site recovery kit.
7. Check the bucket: `mise exec -- ovhcloud cloud storage object bucket
   get <bucket-name> --cloud-project <project-id>`. Versioning shows
   `enabled`.
8. Store a copy of the encrypted `terraform/bootstrap/terraform.tfstate`
   file in the recovery kit, next to the passphrase.
9. Run the local checks: `task verify`.

The bootstrap root is now frozen. Use `task tf:bootstrap-plan` to check
for drift. Do not add resources to this root.
