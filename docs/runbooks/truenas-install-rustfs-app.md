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
7. Set `rustfs_app_certificate_id` to an existing TrueNAS certificate. The
   endpoint name must match it. Without a certificate the chart serves HTTP.
8. Allow the API port only from the operator and Talos networks in the NAS
   firewall. The chart publishes the port on every interface and accepts only
   a wildcard bind address.
9. Copy `terraform/rustfs/gen8/gen8.local.auto.tfvars.example` to
   `gen8.local.auto.tfvars` in that root, and fill it. Set `rustfs_endpoint`
   to the host name the certificate covers and the API port, then enter one
   key pair per bucket. An endpoint on a bare address fails with
   `doesn't contain any IP SANs`. Add that name to the resolver, in DNS or
   `/etc/hosts`, for OpenTofu and for every client.
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

```sh
task tf:rustfs-gen8-plan
task tf:rustfs-gen8-apply
```

Each bucket gets one user, one policy, and one quota. The policy allows only
the actions its client needs. The backup tool for `k8s-backups` is still open,
so its policy is provisional.

Stop on any deletion. Removing or renaming a bucket entry plans the bucket's
destruction.

## Check the result

After the TrueNAS apply:

- The installed chart version matches the pin, and the application is healthy.
- The API answers over verified HTTPS on the NAS address and port.
- The console port isn't published.
- User `568` can write to `/mnt/tank/rustfs`.

After the RustFS apply, test each key with throwaway objects:

- Each key performs its required actions on its own bucket.
- Each key fails to reach the other two buckets.
- No key can administer its own bucket.
- Every quota is positive and leaves headroom on `tank` for snapshots and the
  other datasets.
