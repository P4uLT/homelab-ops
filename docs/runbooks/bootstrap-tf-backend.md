# Bootstrap the Terraform state backend

One-time procedure. It creates the OVH S3 bucket that stores Terraform
state, plus its access chain. The design lives in
`terraform/BACKEND.md`. Re-running any step is safe. Everything
converges.

## Prerequisites

- The `OVH_*` and `TF_STATE_PASSPHRASE` values from `.env.example`,
  filled into your local `.env` file.
- Owner approval, because this creates billable resources.

## Mint the OVH API credentials

The OVH API needs three values: an application key, an application
secret, and a consumer key. The key pair identifies an API
application. The consumer key binds that application to your account.
They can touch your whole account, so treat them like the age key.
They stay in the git-ignored `.env` and in the recovery kit. Never in
a tracked file, shell history, or ticket.

Pick one of the two paths below. Path A is faster. Path B gives you a
scoped credential.

### Path A. Log in with the CLI (recommended)

1. Run `mise exec -- ovhcloud login`.
2. The CLI prints a URL. Open it in a browser.
3. Log in to your OVHcloud account. Approve the access request.
4. Run `mise exec -- ovhcloud config show`. It lists the three keys.
5. Copy them into `.env`: `OVH_APPLICATION_KEY`,
   `OVH_APPLICATION_SECRET`, `OVH_CONSUMER_KEY`.

The login flow creates a full-access credential. The CLI keeps its own
copy under `~/.config/ovhcloud/`, outside the repository.

### Path B. Create the keys on the web page

1. Open `https://www.ovh.com/auth/api/createToken`.
2. Fill the application name and description. Example name:
   `homelab-ops-terraform`.
3. Pick the expiration. `Unlimited` fits infrastructure credentials
   that must not break mid-flight. Rotate them deliberately instead.
4. Add the scope rules. The bootstrap root needs:

   | Method | Path |
   |---|---|
   | GET, POST, PUT, DELETE | `/cloud/project/*` |
   | GET | `/service/*` |

5. Submit. The page shows all three keys once. Copy them into `.env`
   right away: `OVH_APPLICATION_KEY`, `OVH_APPLICATION_SECRET`,
   `OVH_CONSUMER_KEY`.

Path B does not configure the `ovhcloud` CLI. Step 7 uses the CLI, so
run `ovhcloud login` afterwards, or check the bucket with a scoped
tool of your choice instead.

### Check the credentials

Run `mise exec -- ovhcloud cloud project list`. It lists your Public
Cloud projects. The command proves the three keys work. Note the
`project_id` of your project. It is the value for
`OVH_CLOUD_PROJECT_SERVICE` in `.env`.

## Steps

1. Fill the credential values from the section above into `.env`.
   Restrict the file to your user: `chmod 600 .env`.
2. Choose the bucket name and region. Fill `OVH_BUCKET` and
   `OVH_REGION` in `.env`. Keep the name out of any tracked file.
3. Download the provider: `task tf:bootstrap-init`.
4. Preview: `task tf:bootstrap-plan`. Expect five resources to add.
5. Create: `task tf:bootstrap-apply`.
6. Read the credentials. The apply masks both values, so read them
   explicitly:

   ```sh
   task tf:bootstrap-output -- -raw s3_access_key
   task tf:bootstrap-output -- -raw s3_secret_key
   ```

   Copy them into `.env` (`OVH_S3_ACCESS_KEY`, `OVH_S3_SECRET_KEY`) and
   into the off-site recovery kit.
7. Check the bucket: `mise exec -- ovhcloud cloud storage object bucket
   get <bucket-name> --cloud-project <project-id>`. Versioning shows
   `enabled`.
8. Store a copy of the encrypted `terraform/bootstrap/terraform.tfstate`
   file in the recovery kit, next to the passphrase.
9. Run the local checks: `task verify`.

The bootstrap root is now frozen. Use `task tf:bootstrap-plan` to check
for drift. Do not add resources to this root.
