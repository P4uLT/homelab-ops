# Keep a Proxmox VM image outside Terraform management

Use this procedure to keep an existing image file on Proxmox VE while removing
its download resource from OpenTofu state. This works for any PVE node whose
workload root supports both managed downloads and external image references.
It doesn't convert the image format or change a VM disk.

The commands use Jarvis and `haos` as an example. For another node, use its
workload root, backend key, tfvars file, and plan command. Replace `haos` with
the actual image label in the state address. Don't use the PVE access root.

## Prepare the transfer

1. Get approval to read the backend and the PVE node. Pause other plans and
   applies for the affected workload root until the transfer is complete.
2. Confirm the backend is the Jarvis workload state. Record its current bucket
   object version or preserve an encrypted state copy and its decryption material.
3. Verify the file and its provenance on Proxmox. In `jarvis.local.auto.tfvars`,
   move the `haos` entry from `vm_image_downloads` to `vm_image_files`. Keep its
   label, filename, storage, and content type. Omitted `content_type` means
   `iso`. Keep the VM's `image` reference and all workload settings unchanged.
4. Run `task tf:proxmox-jarvis-plan`. Expect only the managed download to be planned for
   deletion. **Don't apply that plan.** Stop if it schedules any other action.

## Remove the state entry without deleting the file

From the repository root, preview the exact address. Use `sh` or Bash and a
trusted `.env.tf` with shell-compatible assignments. The subshell
keeps the backend credentials out of the parent shell.

```sh
(
  set -a
  . ./.env.tf || exit 1
  set +a
  tofu -chdir=terraform/proxmox/jarvis state rm -dry-run -lock-timeout=5s \
    'proxmox_download_file.vm_image["haos"]'
)
```

Expect exactly `Would remove proxmox_download_file.vm_image["haos"]`.
After approval to write the remote state, repeat the command without `-dry-run`.
Keep locking enabled. This removes the state binding without deleting the file.

## Confirm the result

1. Run a new `task tf:proxmox-jarvis-plan`. Expect no changes to Proxmox resources.
   If a VM references the image, confirm that the lookup succeeds and the VM
   isn't replaced. Otherwise, check the file directly in PVE storage. OpenTofu
   doesn't look up an unreferenced image. Don't apply the earlier plan.
   Stop if the new plan proposes any change.
2. If you need to return the image to OpenTofu management, restore the managed
   download declaration and remove the external reference. Review a plan that
   adopts the verified existing file without replacing it or changing the VM.

See [Recover Terraform state](recover-tf-state.md) if the state itself needs
recovery. Restoring state doesn't restore a deleted file.
