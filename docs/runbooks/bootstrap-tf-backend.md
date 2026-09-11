# Bootstrap the Terraform state backend

One-time procedure. It creates the OVH S3 bucket that stores Terraform
state, plus its access chain. The design lives in
`terraform/BACKEND.md`. Re-running any step is safe. Everything
converges.

## Prerequisites

- The `OVH_*` and `TF_STATE_PASSPHRASE` values from `.env.example`,
  filled into your local `.env` file.
- Owner approval, because this creates billable resources.
- The design in `terraform/BACKEND.md`.

## Mint the OVH API credentials

The OVH API needs three values: an application key, an application
secret, and a consumer key. The key pair identifies an API
application. The consumer key binds that application to your account.
They can touch your whole account, so treat them like the age key.
They stay in the git-ignored `.env` and in the recovery kit. Never in
a tracked file, shell history, or ticket.

Pick one of the two paths below. Path A is faster. Path B creates the
keys by hand, so you control the exact rules.

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
   `homelab-ops-tofu`.
3. Pick the expiration. `Unlimited` fits infrastructure credentials
   that must not break mid-flight. Rotate them deliberately instead.
4. Add the rules. The provider checks the credential at start-up
   with `GET /auth/details`, an account-level call outside
   `/cloud/project`. A token scoped only to `/cloud/project/*` fails
   there. The message reads `OVH client seems to be misconfigured`
   followed by `403 This call has not been granted`.

   **Recommended rules.** Four rules, all on `/*`:

   | Method | Path |
   |---|---|
   | GET | `/*` |
   | POST | `/*` |
   | PUT | `/*` |
   | DELETE | `/*` |

   This is the configuration the provider expects, and the one other
   users report as working. It is also a broad credential that can act
   on the whole account. Treat it like the age key.

   Do not add `PATCH`. The OVH form returns an internal server error.

   **Scoped rules, if you accept the upkeep.** The known minimum for
   the bootstrap root is:

   | Method | Path |
   |---|---|
   | GET | `/auth/details` |
   | GET, POST, PUT, DELETE | `/cloud/project/*` |

   Two caveats:

   - The star does not match the bare path `/cloud/project`. The
     `cloud project list` command needs `GET /cloud/project` as well.
     Without it, read the project ID from the console.
   - Narrow paths produced further `403` errors for other users.
     The message names the method and the path. Add a rule for that
     pair, or move to the recommended rules above.

   For a durable scoped setup, use an OAuth2 service account with an
   IAM policy. See Least privilege below.

5. Submit. The page shows all three keys once. Copy them into `.env`
   right away: `OVH_APPLICATION_KEY`, `OVH_APPLICATION_SECRET`,
   `OVH_CONSUMER_KEY`.

Path B does not configure the `ovhcloud` CLI. Step 7 uses the CLI, so
run `ovhcloud login` afterwards, or check the bucket with a scoped
tool of your choice instead.

### Check the credentials

Reload your shell first (`exec zsh`, or open a new terminal). Your
shell keeps previously exported `OVH_*` values and passes them to the
CLI ahead of `.env`. A fresh `mise exec --` call re-reads `.env`, so it
always sees the current values.

Run `mise exec -- ovhcloud cloud project list`. It lists your Public
Cloud projects. The command proves the three keys work. Note the
`project_id` of your project. It is the value for
`OVH_CLOUD_PROJECT_SERVICE` in `.env`.

### Least privilege (later)

A consumer key scopes by HTTP method and path. That model is fragile
here, because the provider also calls account-level endpoints.

The durable option is an OAuth2 service account plus an IAM policy:

1. `ovh_me_api_oauth2_client` with `flow = "CLIENT_CREDENTIALS"`. It
   outputs `client_id`, `client_secret`, and an identity URN.
2. `ovh_iam_policy` on that identity:

   ```hcl
   resources = ["urn:v1:eu:resource:publicCloudProject:<project_id>"]
   allow     = ["publicCloudProject:apiovh:*"]
   ```

3. The provider then authenticates with `OVH_CLIENT_ID` and
   `OVH_CLIENT_SECRET`.

Three constraints:

- Creating the service account needs an already privileged credential.
  The broad key stays, but it runs once instead of on every apply.
- OVH returns the `client_secret` only at creation. A loss means a new
  client.
- The scope above may not cover the start-up call. Add the
  `account:apiovh:*` action when the first plan asks for it.

Do this after the bootstrap root is stable. It changes a credential,
not the Terraform code.

### `403 This call has not been granted`

The token lacks a method and path pair for the call it made.

1. Read the method and the path from the message.
2. Add a rule for that pair, or replace the rules with the recommended
   ones above.
3. Reload the shell and retry. A stale exported `OVH_*` value makes a
   good rule look broken.

A start-up failure that names no resource comes from `/auth/details`.

## Steps

1. Fill the credential values from the section above into `.env`.
   Restrict the file to your user: `chmod 600 .env`.
2. Choose the bucket name and the region. Fill `OVH_BUCKET` and
   `OVH_REGION` in `.env`. Keep the name out of any tracked file. Use a
   3-AZ region, and enter it in uppercase exactly as the project API
   reports it (`EU-WEST-PAR`, `EU-SOUTH-MIL`). Lowercase returns
   `Invalid region parameter`.
3. Initialize the root: `task tf:init`. It downloads the OVH provider.
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
7. Check the bucket. Versioning shows `enabled`:

   ```sh
   mise exec -- ovhcloud cloud storage object bucket get <bucket-name> \
     --cloud-project "$OVH_CLOUD_PROJECT_SERVICE"
   ```
8. Store a copy of the encrypted `terraform/bootstrap/terraform.tfstate`
   file in the recovery kit, next to the passphrase.
9. Run the local checks: `task verify`.

The bootstrap root is now frozen. Use `task tf:bootstrap-plan` to check
for drift. Do not add resources to this root.
