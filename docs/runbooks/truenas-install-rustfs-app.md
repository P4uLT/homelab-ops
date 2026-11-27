# Install the RustFS application on the Gen8

RustFS is the one application on the NAS. The storage root installs it from
the TrueNAS catalog and publishes its S3 API. The RustFS root owns the
buckets, the users, and the policies.

## Prepare the inputs

Get owner approval before the plan, the apply, and every live check. Mock
tests don't prove the application's behavior.

1. Set `provision_apps = true` in
   `terraform/bootstrap/truenas/gen8/gen8.local.auto.tfvars`.
2. Run `task tf:truenas-gen8-bootstrap-plan`, review it, and apply. The
   provisioner needs the apps roles before the storage root plans the
   application.
3. Add a `rustfs` entry to `datasets` with `share_type = "APPS"`.
4. Mint the admin key pair outside OpenTofu and store it in a password
   manager. Use an access key of 3 to 20 characters and a secret key of 8 to
   40.
5. Enter the pair in both Gen8 tfvars files. The storage root and the RustFS
   root read the same values.
6. Fill the `rustfs_app_*` block in the storage tfvars. Set the version to
   the one the catalog offers, `1.1.47` at the last check. A missing version
   fails the apply with `Version ... not found`.
7. Select a TrueNAS certificate that covers the RustFS DNS name. To use a
   managed wildcard, [issue certificates with OVH DNS](truenas-acme-ovh.md).
   Set `rustfs_app_certificate_id` to the certificate ID.
8. Allow the API port only from the operator and Talos networks in the NAS
   firewall. The chart publishes the port on every interface and accepts only
   a wildcard bind address.
9. Copy `terraform/rustfs/gen8/gen8.local.auto.tfvars.example` to
   `gen8.local.auto.tfvars` in that root. Set `rustfs_endpoint` to the
   HTTPS URL for the certificate's DNS name and the API port.
   Set quotas and enter a separate key pair per bucket.
   Make the name resolve to the NAS for OpenTofu and every client.
10. Run `task tf:init` once. It downloads the RustFS provider.

The provider has no data source for the catalog version, so it stays a pinned
input. Read it from the TrueNAS Apps catalog before the first apply.

## Install the application

```sh
task tf:truenas-gen8-plan
task tf:truenas-gen8-apply
```

Review the plan before the apply. Expect the Docker configuration, the catalog
configuration, and the application. Stop on any deletion or replacement. The
plan masks the application `values` on purpose: both keys travel inside it.

Turning the gate off after install plans removal. That's a teardown, not a way
to stop the application.

## Create the buckets and users

Trust the issuing certificate authority on the OpenTofu machine and each
client. For a private authority, install its public CA certificate or set
`SSL_CERT_FILE` to the `PEM` bundle for the RustFS task. Keep `rustfs_ssl = true`
and `rustfs_insecure = false`.

Before planning the buckets, set `RUSTFS_URL` to the configured endpoint and
check the health route without credentials:

```sh
curl --fail --silent --show-error "$RUSTFS_URL/health"
```

If the issuing authority isn't in the system trust store, add `--cacert`
with the public CA bundle to the `curl` command.

If your local tfvars use `quota_bytes`, replace it with `quota_gib` and divide
the old value by `1073741824`. Keep the bucket names and access keys unchanged.
For `wal-g` and `loki`, carry over `s3:DeleteObject` in
`additional_object_actions` to keep their existing permissions.

```sh
task tf:rustfs-gen8-plan -- -out=review.tfplan
# Review the plan before applying it.
task tf:rustfs-gen8-apply -- review.tfplan
```

Each bucket gets one user, one policy, and one quota. The default policy allows
bucket listing and object reads, writes, and multipart uploads. Add actions
only when the client needs them. The backup tool for `k8s-backups` is still
open, so its policy is provisional.

The plan reads the cluster before it writes. It fails when the cluster is
offline, when a disk is offline, or when a bucket `location_constraint`
differs from the server region. Omit the constraint on the server's own
region: `us-east-1` is the default and isn't an accepted value, and `EU` is
the accepted alias for `eu-west-1`.
It also warns when RustFS holds a bucket that the catalog doesn't declare.

This root exports no Terraform outputs. The first plan may remove outputs
stored in the state. Review that state change like any other plan.

Stop on any deletion or replacement. Removing or renaming a bucket entry
plans its destruction. Changes to Object Lock, the namespace, or creation
options such as tags plan replacement. Keep `force_destroy` off to prevent
deletion of non-empty buckets. Removing a configured `versioning` value
suspends versioning.

## Check the result

After the TrueNAS apply:

- The installed chart version matches the pin, and the application is healthy.
- The API answers over verified HTTPS at the configured DNS name and port.
- The console port isn't published.
- User `568` can write to `/mnt/tank/rustfs`.

After the RustFS apply, test each key with throwaway objects:

- Each key performs its required actions on its own bucket.
- Each key fails to reach the other buckets.
- No key can administer its own bucket.
- Every quota is positive and leaves headroom on `tank` for snapshots and the
  other datasets.

## Read live capacity

Run `mise install` to install the pinned official RustFS CLI (`rc`).
Get owner approval before contacting the NAS.
Use an identity authorized to read storage and quota information. Prepare the
`RC_HOST_gen8` value in your password manager. Replace `NAS_HOST` with the DNS
name covered by the certificate and use the published API port.

```text
https://ACCESS_KEY:SECRET_KEY@NAS_HOST:30292
```

Percent-encode special characters in the keys. For example, encode `+` as
`%2B`, `/` as `%2F`, and `=` as `%3D`. See the CLI's
[environment alias format](https://github.com/rustfs/cli/blob/v0.1.38/README.md#basic-operations).
Don't put credentials in command arguments or save an alias with keys.

In zsh, paste the URL at the hidden prompt. The parentheses limit the alias
export to these commands:

```zsh
(
  read -rs 'RC_HOST_gen8?RustFS URL: ' || exit 1
  printf '\n'
  [[ -n $RC_HOST_gen8 ]] || exit 1
  export RC_HOST_gen8
  task tf:rustfs-gen8-status && task tf:rustfs-gen8-quota BUCKET=k8s-backups
)
```

Pass `-- --json` for the CLI's machine-readable output. The CLI uses its
own display units. Storage capacity and the bucket quota are separate
measures. Usage may be absent if the quota endpoint doesn't report it.
Neither task needs OpenTofu state or a plan.

## Check certificate renewal

If TrueNAS manages renewal, check the certificate that RustFS serves after
each renewal. TrueNAS redeploys apps that use the renewed certificate.
If RustFS still serves the old one, check the redeploy job before retrying.

If you import a replacement certificate, set `rustfs_app_certificate_id` to
its new ID. Apply the TrueNAS root after owner approval. Verify HTTPS with
the configured DNS name before removing the old certificate.
