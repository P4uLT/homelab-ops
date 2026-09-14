# Runbooks

Operational procedures for servers, storage, and the images they run. Every
runbook touches a real host or a billable resource, so get owner approval
before the run.

## Servers

- [Add a Proxmox VE node](onboard-pve.md) — inventory entry, secrets, SSH
  access, storages, first image build.
- [Pin a host key](pin-host-keys.md) — verify a node fingerprint and pin it
  before Ansible contacts it.

## Terraform access and state

- [Bootstrap the PVE access of the Terraform roots](bootstrap-pve-access.md) —
  mint the API token the workload roots use.
- [Bootstrap the Terraform state backend](bootstrap-tf-backend.md) — the
  one-time OVH S3 bucket and its credentials.
- [Rotate the S3 credential](rotate-s3-credential.md) — replace a leaked or
  ageing access key pair.

## Images and workloads

- [Build the golden images](build-base-image.md) — Packer builds a container
  template and packs it as a versioned archive.
- [Provision an LXC workload with Terraform](provision-pve-ct.md) — clone a
  golden image into a running container.

## Design

The why behind these procedures lives outside this directory:

- [Terraform state design](../../terraform/BACKEND.md)
- [OVH object storage conventions](../object-storage.md)
- [OVH least privilege](../ovh-least-privilege.md) — why the bootstrap
  credential is broad, and what replaces it.
