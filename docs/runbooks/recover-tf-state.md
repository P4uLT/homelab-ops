# Recover Terraform state

Restore state records after state corruption or backend loss.
State restoration doesn't restore infrastructure or application data.

## Before starting

- Get owner approval for the affected root and recovery method.
- For a backup restore, prepare the approved state copy with its passphrase and encryption configuration.
- Use the [recovery kit](../../terraform/BACKEND.md#recovery) for saved credentials and recovery records.

Off-site copies are planned. Bucket-loss recovery isn't qualified here.

## Restore a state file

1. Pause plans and applies for the affected root.
2. Preserve the current state before restoring a bucket version or encrypted backup.
3. Restore the selected state with its matching decryption settings.
4. Review resource addresses, including migrations after the snapshot.
5. Inspect a plan before resuming infrastructure changes.
   Stop on unexpected creation, replacement, or deletion.

Noncurrent bucket versions expire after 90 days.

## Recover after bucket loss

1. Recover the [bootstrap root](#recover-the-bootstrap-root) before reviewing a replacement bucket and its access policy.
2. Restore each root's encrypted state to its intended backend location before resuming plans.
3. If no usable state copy exists, import existing resources through a reviewed recovery plan.

Don't apply an empty state to existing infrastructure.
That can create duplicate resources or fail on existing objects.

## Recover the bootstrap root

1. If a usable copy exists, restore the bootstrap root's encrypted local state from the recovery kit.
2. If no usable copy exists, import existing access resources instead of recreating the access chain.
3. Use saved credentials or review a separate rotation.

Imports don't recover secrets returned only at credential creation.

## Related

- [Terraform state design](../../terraform/BACKEND.md)
- [Bootstrap the state backend](bootstrap-tf-backend.md)
- [Rotate the S3 credential](rotate-s3-credential.md)
