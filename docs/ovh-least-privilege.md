# OVH least privilege

OVH consumer keys restrict HTTP methods and paths. The Terraform provider also
uses account-level endpoints, so project-only rules aren't sufficient.

## Bootstrap key

The provider validates its credential at start-up with `GET /auth/details`,
an account-level call outside `/cloud/project`. A key scoped only to
`/cloud/project/*` fails there. The message reads `OVH client seems to be
misconfigured`, followed by `403 This call has not been granted`.

Narrow rules can require additional method/path pairs as provider calls change.
The one-time bootstrap uses `GET`, `POST`, `PUT`, and `DELETE` on `/*`.
This grants account-wide access. Protect the credential like the age key.

## The durable option

The scoped alternative uses an OAuth2 service account and an IAM policy.

- `ovh_me_api_oauth2_client` uses `flow = "CLIENT_CREDENTIALS"`. Its outputs are
  `client_id`, `client_secret`, and an identity URN.
- `ovh_iam_policy` defines resources and permissions for that identity:

   ```hcl
   resources = ["urn:v1:eu:resource:publicCloudProject:<project_id>"]
   allow     = ["publicCloudProject:apiovh:*"]
   ```

- The provider authenticates with `OVH_CLIENT_ID` and `OVH_CLIENT_SECRET`.

## What it costs

- Creating the service account requires a privileged credential. Use the broad
  key for this setup rather than routine applies.
- OVH returns the `client_secret` only at creation. A loss means a new
  client.
- The scope above may not cover the start-up call. If required, add
  `account:apiovh:*` for account-level authentication checks.

## When to do it

Adopt scoped authentication after the bootstrap root is stable.
This changes provider credentials without changing the infrastructure configuration.

## Related

- [Bootstrap the Terraform state backend](runbooks/bootstrap-tf-backend.md)
  for credential setup.
- [Terraform state design](../terraform/BACKEND.md) for what the key
  protects and how the state recovers.
