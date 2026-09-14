# Bootstrap the Terraform state backend

One-time procedure. It creates the OVH S3 bucket that stores Terraform state,
plus its access chain. The design is in
[Terraform state design](../../terraform/BACKEND.md). Re-running any step is
safe: everything converges.

Two things happen here, in order. First you mint the OVH API credentials, then
you create the bucket with them.

## Prerequisites

Have these ready before you start:

- The `OVH_*` values from `.env.account.ovh.tf.example` and
  `TF_VAR_state_passphrase` from `.env.tf.example`, filled into the matching
  local files.
- Owner approval, because this creates billable resources.
- The design in [Terraform state design](../../terraform/BACKEND.md).

## Mint the OVH API credentials

The OVH API needs three values: an application key, an application secret, and
a consumer key. The key pair identifies an API application. The consumer key
binds that application to your account. They can touch your whole account, so
treat them like the age key. They stay in the git-ignored
`.env.account.ovh.tf` and in the recovery kit. Never in a tracked file, shell
history, or ticket.

Pick one of the two paths below. Path A is faster. Path B creates the keys by
hand, so you control the exact rules.

### Path A. Log in with the CLI (recommended)

The browser flow mints all three keys at once, with full access.

1. Run `mise exec -- ovhcloud login`.
2. The CLI prints a URL. Open it in a browser.
3. Log in to your OVHcloud account. Approve the access request.
4. Run `mise exec -- ovhcloud config show`. It lists the three keys.
5. Copy them into `.env.account.ovh.tf`: `OVH_APPLICATION_KEY`,
   `OVH_APPLICATION_SECRET`, `OVH_CONSUMER_KEY`.

The login flow creates a full-access credential. The CLI keeps its own copy
under `~/.config/ovhcloud/`, outside the repository.

### Path B. Create the keys on the web page

Use this path when you want to choose the rules the key carries.

1. Open `https://www.ovh.com/auth/api/createToken`.
2. Fill the application name and description. Example name:
   `homelab-ops-tofu`.
3. Pick the expiration. `Unlimited` fits infrastructure credentials that must
   not break mid-flight. Rotate them deliberately instead.
4. Add the rules. The provider checks the credential at start-up with
   `GET /auth/details`, an account-level call outside `/cloud/project`. A
   token scoped only to `/cloud/project/*` fails there. The message reads
   `OVH client seems to be misconfigured` followed by
   `403 This call has not been granted`.

   **Recommended rules.** Four rules, all on `/*`:

   | Method | Path |
   | --- | --- |
   | GET | `/*` |
   | POST | `/*` |
   | PUT | `/*` |
   | DELETE | `/*` |

   This is the configuration the provider expects, and the one other users
   report as working. It is also a broad credential that can act on the whole
   account. Treat it like the age key.

   Do not add `PATCH`. The OVH form returns an internal server error.

   **Scoped rules, if you accept the upkeep.** The known minimum for the
   bootstrap root is:

   | Method | Path |
   | --- | --- |
   | GET | `/auth/details` |
   | GET, POST, PUT, DELETE | `/cloud/project/*` |

   Two caveats:

   - The star does not match the bare path `/cloud/project`. The
     `cloud project list` command needs `GET /cloud/project` as well. Without
     it, read the project ID from the console.
   - Narrow paths produced further `403` errors for other users. The message
     names the method and the path. Add a rule for that pair, or move to the
     recommended rules above.

   For a durable scoped setup, use an OAuth2 service account with an IAM
   policy. See [OVH least privilege](../ovh-least-privilege.md).

5. Submit. The page shows all three keys once. Copy them into
   `.env.account.ovh.tf` right away: `OVH_APPLICATION_KEY`,
   `OVH_APPLICATION_SECRET`, `OVH_CONSUMER_KEY`.

Path B does not configure the `ovhcloud` CLI, and step 7 below uses it. Run
`ovhcloud login` afterwards, or check the bucket with a scoped tool of your
choice instead.

### Check the credentials

One command proves the three keys reach your account.

Run `task ovh:cli -- cloud project list`. It lists your Public Cloud projects,
which proves the three keys work. The task loads `.env.account.ovh.tf` for
that one command, so nothing lands in your shell. Note the `project_id`. It is
the value for `OVH_CLOUD_PROJECT_SERVICE` in `.env.account.ovh.tf`.

## Create the bucket and its access chain

The run takes the credentials from the section above and ends with a frozen
root. Step 5 creates billable resources, so get owner approval first.

1. Fill the credential values from the section above into
   `.env.account.ovh.tf`, and `TF_VAR_state_passphrase` into `.env.tf`.
   Restrict both files to your user: `chmod 600`.
2. Choose the bucket name and the region. Fill `TF_VAR_bucket_name` in
   `.env.tf`, and `region` in `terraform/bootstrap/ovh/ovh.local.auto.tfvars`.
   Keep both values out of any tracked file. Use a 3-AZ region, and enter it
   in uppercase exactly as the project API reports it (`EU-WEST-PAR`,
   `EU-SOUTH-MIL`). Lowercase returns `Invalid region parameter`.
3. Initialize the root: `task tf:init`. It downloads the OVH provider.
4. Preview: `task tf:bootstrap-plan`. Expect five resources to add.
5. Create: `task tf:bootstrap-apply`.
6. Read the credentials. The apply masks both values, so read them explicitly:

   ```sh
   task tf:bootstrap-output -- -raw s3_access_key
   task tf:bootstrap-output -- -raw s3_secret_key
   ```

   Copy them into `.env.tf` (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
   and into the off-site recovery kit.
7. Check the bucket. Versioning shows `enabled`:

   ```sh
   mise exec -- ovhcloud cloud storage object bucket get <bucket-name> \
     --cloud-project "$OVH_CLOUD_PROJECT_SERVICE"
   ```

8. Store a copy of the encrypted
   `terraform/bootstrap/ovh/terraform.tfstate` file in the recovery kit, next
   to the passphrase.
9. Run the local checks: `task verify`.

The bootstrap root is frozen now. Use `task tf:bootstrap-plan` to check for
drift. Do not add resources to this root.

## When the API returns `403 This call has not been granted`

The token lacks a method and path pair for the call it made.

1. Read the method and the path from the message.
2. Add a rule for that pair, or replace the rules with the recommended ones
   above.
3. Reload the shell and retry. A stale exported `OVH_*` value makes a good
   rule look broken.

A start-up failure that names no resource comes from `/auth/details`.

## Next steps

- [Rotate the S3 credential](rotate-s3-credential.md) when the key pair may
  have leaked.
- [OVH least privilege](../ovh-least-privilege.md) to stop using the broad
  account key on every apply.
- [Provision an LXC workload with Terraform](provision-pve-ct.md) — the first
  root that writes state to this bucket.
