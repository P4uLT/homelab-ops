# OVH least privilege

An OVH consumer key scopes by HTTP method and path, and by nothing else. That
model is fragile for the Terraform provider, because the provider also calls
account-level endpoints. This page explains why the bootstrap credential is
broad, and what replaces it.

## Why the broad key

The provider validates its credential at start-up with `GET /auth/details`,
an account-level call outside `/cloud/project`. A key scoped only to
`/cloud/project/*` fails there. The message reads `OVH client seems to be
misconfigured`, followed by `403 This call has not been granted`.

Narrow paths produced further `403` errors for other users. Each failure
names a method and a path, so a scoped key needs a rule added every time the
provider reaches somewhere new. The bootstrap root runs once, so the upkeep
buys nothing there.

The result is four rules, all on `/*`: `GET`, `POST`, `PUT`, `DELETE`. The
provider expects that shape, and other users report it as working. The
credential can act on the whole account, so treat it like the age key.

## The durable option

An OAuth2 service account plus an IAM policy:

1. `ovh_me_api_oauth2_client` with `flow = "CLIENT_CREDENTIALS"`. It outputs
   `client_id`, `client_secret`, and an identity URN.
2. `ovh_iam_policy` on that identity:

   ```hcl
   resources = ["urn:v1:eu:resource:publicCloudProject:<project_id>"]
   allow     = ["publicCloudProject:apiovh:*"]
   ```

3. The provider then authenticates with `OVH_CLIENT_ID` and
   `OVH_CLIENT_SECRET`.

## What it costs

Three things make the durable option slower to adopt than the broad key:

- Creating the service account needs an already privileged credential. The
  broad key stays, but it runs once instead of on every apply.
- OVH returns the `client_secret` only at creation. A loss means a new
  client.
- The scope above may not cover the start-up call. Add the
  `account:apiovh:*` action when the first plan asks for it.

## When to do it

After the bootstrap root is stable. It changes a credential, not the
Terraform code.

## Next steps

- [Bootstrap the Terraform state backend](runbooks/bootstrap-tf-backend.md)
  for the root that mints the credential.
- [Terraform state design](../terraform/BACKEND.md) for what the key
  protects and how the state recovers.
