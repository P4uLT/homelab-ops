# Runbooks

Get owner approval before host contact or changes to cloud resources.
Check mode can change a node.

## Servers

- [Add a Proxmox VE node](onboard-pve.md): inventory, access, storage, and images.
- [Pin a host key](pin-host-keys.md): verify the fingerprint before connecting.

## Terraform access and state

- [Bootstrap PVE access](bootstrap-pve-access.md): create the workload API token.
- [Bootstrap TrueNAS](bootstrap-truenas.md): create the pool and provisioning access.
- [Share over NFS](truenas-share-nfs.md): serve a dataset to NFS clients.
- [Share over SMB](truenas-share-smb.md): serve a dataset to Windows clients.
- [Share over SMB and NFS](truenas-share-multiprotocol.md): serve one dataset to both.
- [Set dataset permissions](truenas-dataset-permissions.md): grant access through OpenTofu.
- [Recover TrueNAS storage](recover-truenas-storage.md): adopt a pool or recreate a dataset.
- [Bootstrap the state backend](bootstrap-tf-backend.md): create the OVH S3 bucket and credentials.
- [Rotate the S3 credential](rotate-s3-credential.md): replace the backend key pair.
- [Move Terraform code or state](move-tf-state.md)
- [Recover Terraform state](recover-tf-state.md)

## Images and workloads

- [Build and qualify golden images](build-base-image.md)
- [Provision an LXC workload](provision-pve-ct.md)
- [Provision a Proxmox VM from a disk image](provision-pve-vm.md)
- [Keep a Proxmox VM image outside Terraform management](retain-pve-vm-image.md)
- [Override the Packer plugin locally](override-packer-plugin.md): install a development binary and restore the pinned release, without node contact.

## Design

- [Terraform state design](../../terraform/BACKEND.md)
- [OVH object storage conventions](../object-storage.md)
- [OVH least privilege](../ovh-least-privilege.md)
