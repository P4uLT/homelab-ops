# Provision a Proxmox VM from a disk image

Use a workload root that supports external QCOW2 files in Proxmox VE Import
storage. OpenTofu creates the VM through the Proxmox API. It doesn't manage the
source file or need SSH for this disk import.

## Check the workload state

Get owner approval before contacting the node or the backend. Choose the
workload root for the target node and verify its backend key. If the node was
reinstalled, compare the existing state with the resources that survived.
Preserve the old state and get approval before switching to an empty state.
See [Move Terraform code or state](move-tf-state.md).

If OpenTofu already manages the source file, follow
[Keep a Proxmox VM image outside Terraform management](retain-pve-vm-image.md)
before switching the image reference. If the node lacks a workload token,
follow [Bootstrap PVE access](bootstrap-pve-access.md).

## Prepare the image and inputs

1. Verify the publisher's checksum before extracting the QCOW2 archive.
2. Place the extracted file on a datastore that allows Import content.
   Verify the stored file against the extracted copy. The workload root checks
   the filename, not the file's checksum.
3. Add the exact filename and datastore to `vm_image_files`. Set
   `content_type = "import"`. Reference the image label from `vm_workloads`.
4. Choose an unused VM ID. Keep the workload map key stable after creation.
   Check that the target disk and firmware datastores and network bridge exist.
5. Keep existing workload declarations unchanged when adding a VM to an
   existing state. If you're replacing a service, verify its backup and any
   required recovery key outside the node before erasing its old disks.

## Review and apply

After approval and initialization, save a full plan from the workload root.
Set `ROOT` to its path, and set `PLAN` to an absolute path in a private
directory. Load the backend credentials as for the node's OpenTofu tasks.

```sh
tofu -chdir="$ROOT" plan -out="$PLAN"
```

The only Proxmox change should be creation of the intended VM. Stop if the plan
changes any other workload or destroys an image. Don't use targeting to hide
unrelated changes. After separate approval, apply that exact plan:

```sh
tofu -chdir="$ROOT" apply "$PLAN"
```

Check that the VM boots and the service is reachable. Keep the plan outside
Git and remove it after use. Upgrade the guest from inside the guest rather
than changing the VM's source image.
