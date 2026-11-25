# image_finalize

Seal a Debian golden image without leaving a shared clone identity.

## Decision and scope

Run after the final boot and package installation: later steps can recreate
identity or cache state. Sealing is an image operation, separate from runtime
population policy.
The target needs privileged access, systemd, and facts gathered earlier in the build.
Missing build-time facts fail before identity changes.

## Interface

The [argument specifications](meta/argument_specs.yml) require the image name, version, and parent.
The build marker uses those inputs and the previously gathered fact timestamp.

## Flow

- [Identity](tasks/identity.yml): install and enable next-boot host-key generation,
  lock the root password, remove shared host keys, and empty the machine identity.
- [Entry point](tasks/main.yml): record the image build in `/etc/image-build-info`.
- [Package state](tasks/packages.yml): clean unused packages and archives,
  then remove and recreate the empty package-list directory.
- [Verification](tasks/verify.yml): require an existing empty machine identity and no host keys.

The root password lock has a read-only verification inside the identity phase.
Keep the fixed paths, root lock, and [host-key unit](files/ssh-host-keys.service)
outside population configuration. Reload the daemon before enabling the unit,
instead of deferring this to a handler after sealing.

## Verification limits

Check mode doesn't perform removals, so final assertions can fail on an unsealed image.
A marker timestamp and cache-directory recreation can report changes on a repeated build.
Don't describe this lifecycle role as proof of a runtime baseline's idempotence.

Use image syntax checks, production-profile lint, and `task verify`.
Get owner approval before real provisioning or clone-identity checks.
