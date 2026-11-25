# Bootstrap the Terraform state backend

Create the OVH API credentials, then the state bucket and its access chain.
See [Terraform state design](../../terraform/BACKEND.md) for the frozen bootstrap root.

## Prerequisites

- The `OVH_*` values from `.env.account.ovh.tf.example` and
  `TF_VAR_state_passphrase` from `.env.tf.example`, filled into the matching
  local files.
- Owner approval, because this creates billable resources.
- The design in [Terraform state design](../../terraform/BACKEND.md).

## Create the OVH API credentials

The application key and secret identify the API application. The consumer key
authorizes it on your account. These account-wide credentials need the same
protection as the age key. Store them in git-ignored `.env.account.ovh.tf` and
the recovery kit, not tracked files, shell history, or tickets.

Use the CLI browser flow, or the web page to choose permission rules.

### Path A. Log in with the CLI (recommended)

The browser flow creates all three keys with full access.

1. Run `ovhcloud login`.
2. The CLI prints a URL. Open it in a browser.
3. Log in to your OVHcloud account. Approve the access request.
4. Run `ovhcloud config show`. It lists the three keys.
5. Copy them into `.env.account.ovh.tf`: `OVH_APPLICATION_KEY`,
   `OVH_APPLICATION_SECRET`, `OVH_CONSUMER_KEY`.

The login flow creates a full-access credential. The CLI keeps its own copy
under `~/.config/ovhcloud/`, outside the repository.

### Path B. Create the keys on the web page

1. Open `https://www.ovh.com/auth/api/createToken`.
2. Fill the application name and description. Example name:
   `homelab-ops-tofu`.
3. Pick the expiration. `Unlimited` fits credentials that must remain valid during infrastructure operations.
   Rotate them deliberately instead.
4. Add the rules. The provider checks the credential at start-up with
   `GET /auth/details`, an account-level call outside `/cloud/project`. A
   token scoped only to `/cloud/project/*` fails there. The message reads
   `OVH client seems to be misconfigured` followed by
   `403 This call has not been granted`.

   **Recommended rules:**

   | Method | Path |
   | --- | --- |
   | GET | `/*` |
   | POST | `/*` |
   | `PUT` | `/*` |
   | DELETE | `/*` |

   Don't add `PATCH`. The OVH form returns an internal server error.

   **Scoped rules, if you accept the upkeep.** The known minimum for the
   bootstrap root is:

   | Method | Path |
   | --- | --- |
   | GET | `/auth/details` |
   | `GET`, `POST`, `PUT`, `DELETE` | `/cloud/project/*` |

   - The star doesn't match the bare path `/cloud/project`. The
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

Path B doesn't configure the `ovhcloud` CLI, and step 7 below uses it. Run
`ovhcloud login` afterwards, or check the bucket with a scoped tool of your
choice instead.

### Check the credentials

Run `task ovh:cli -- cloud project list` to check account access and get the
`project_id` for `OVH_CLOUD_PROJECT_SERVICE` in `.env.account.ovh.tf`.
The task loads the credentials for that command only.

## Create the bucket and its access chain

Get owner approval before creating billable resources in step 5.

1. Fill the credential values from the section above into
   `.env.account.ovh.tf`, and `TF_VAR_state_passphrase` into `.env.tf`.
   Restrict both files to your user: `chmod 600`.
2. Choose the bucket name and the region. Fill `TF_VAR_bucket_name` in
   `.env.tf`, and `region` in `terraform/bootstrap/ovh/ovh.local.auto.tfvars`.
   Keep both values out of tracked files. Use a 3-AZ region.
   Enter its code in uppercase exactly as the project API reports it (`EU-WEST-PAR`,
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
   ovhcloud cloud storage object bucket get <bucket-name> \
     --cloud-project "$OVH_CLOUD_PROJECT_SERVICE"
   ```

8. Store a copy of the encrypted
   `terraform/bootstrap/ovh/terraform.tfstate` file in the recovery kit, next
   to the passphrase.
9. Run the local checks: `task verify`.

Use `task tf:bootstrap-plan` for drift checks. Keep the bootstrap root frozen
without additional resources.

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
- [Provision an LXC workload with Terraform](provision-pve-ct.md): the first
  root that writes state to this bucket.
