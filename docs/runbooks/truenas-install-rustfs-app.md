# Install the RustFS application on the Gen8

RustFS is the one application on the NAS. The storage root installs it from
the TrueNAS catalog and publishes its S3 API. The RustFS root owns the
buckets, the users, and the policies.

## Prepare the inputs

Get owner approval before the plan, the apply, and every live check. Mock
tests don't prove the application's behavior.

1. Add a `rustfs` entry to `datasets` with `share_type = "APPS"`.
2. Mint the admin key pair outside OpenTofu and store it in a password
   manager. Use an access key of 3 to 20 characters and a secret key of 8 to
   40.
3. Enter the pair in both Gen8 tfvars files. The storage root and the RustFS
   root read the same values.
4. Fill the `rustfs_app_*` block in the storage tfvars. Set the version to
   chart `1.1.46`, which packages RustFS `1.0.6`. Confirm the catalog still
   offers that version.
5. Set `rustfs_app_certificate_id` to an existing TrueNAS certificate. The
   endpoint name must match it. Without a certificate the chart serves HTTP.
6. Set `rustfs_app_api_bind_ip` to one approved interface address. Open the
   API port only to the operator and Talos networks.

## Install the application

```sh
task tf:truenas-gen8-plan
task tf:truenas-gen8-apply
```

Review the plan before the apply. Expect the Docker configuration, the catalog
configuration, and the application. Stop on any deletion or replacement.

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

## Check the result

After the TrueNAS apply:

- The installed chart version matches the pin, and the application is healthy.
- The API answers over verified HTTPS on the approved address and port.
- The console port isn't published.
- User `568` can write to `/mnt/tank/rustfs`.

After the RustFS apply, test each key with throwaway objects:

- Each key performs its required actions on its own bucket.
- Each key fails to reach the other two buckets.
- No key can administer its own bucket.
- Every quota is positive and leaves headroom on `tank` for snapshots and the
  other datasets.
