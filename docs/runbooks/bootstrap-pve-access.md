# Bootstrap the PVE access of the Terraform roots

`terraform/bootstrap/pve/jarvis/` manages the role, group, `terraform-prov@pve`
user, ACL on `/`, and workload API token for jarvis. Ansible doesn't manage them.
The root is frozen, with `prevent_destroy` on each resource. Review changes in a commit.

Issue a separate access-management token before running the root.
Store it with the endpoint in the root's git-ignored `jarvis.local.auto.tfvars`.
Authentication uses the API, without passwords or SSH.

Remote state uses `bootstrap/pve/jarvis/terraform.tfstate` in the existing shared
bucket. The encrypted state contains the workload token and needs versioning
and recovery-kit protection.

## Issue the access-management token

Get owner approval before changing PVE permissions or issuing the token.
Use the PVE interface at Datacenter > Permissions with an administrator account.

1. Add a role named `Terraform_AccessBootstrap` with these privileges:

   ```text
   Group.Allocate Permissions.Modify Realm.AllocateUser Sys.Audit Sys.Modify User.Modify
   ```

2. Add an API token for `root@pam` with token ID `terraform-bootstrap`.
   Keep Privilege Separation enabled. Set an expiration for the maintenance window.
3. Copy the secret shown at creation into the local file described below.
4. Add an API token permission on `/` for `root@pam!terraform-bootstrap`.
   Select `Terraform_AccessBootstrap`. Enable propagation.

`Permissions.Modify` on `/` can grant cluster-wide access to groups, users,
roles, ACLs, and tokens. Protect this administrative credential separately from
workload tokens. OpenTofu doesn't need the account password.
The [PVE user-management guide](https://pve.proxmox.com/pve-docs/chapter-pveum.html)
describes token permission separation.

This root doesn't manage the bootstrap token or its role.
Don't use `terraform-prov@pve!tf` here: that token lacks the access-management
privileges and belongs in the workload root instead.

## Run the access root

Prepare `.env.tf` with the state backend credentials and encryption passphrase.
Get owner approval before any step that contacts the node.

1. Create `terraform/bootstrap/pve/jarvis/jarvis.local.auto.tfvars` from its
   `.example`, mode 600, with the endpoint and access-management token.
   In an existing file, replace `pve_username` and `pve_password` with `pve_api_token`.
   Set the token as `root@pam!terraform-bootstrap=<secret>`.
   Replace `<secret>` with the value copied at creation.
   Don't overwrite the workload root's local file.
2. Initialize the roots with `task tf:init`.
   This reads the remote state backend, not the PVE node.
3. Plan with `task tf:pve-jarvis-plan`.
   Leave `adopt_existing_access` at its default to import the existing role,
   group, user, and ACL. Set it to `false` only for a clean PVE node with a
   fresh access state. That plan creates the access objects instead of
   importing them. For existing state, review the [address mappings](#recovery).
4. Apply: `task tf:pve-jarvis-apply -- -auto-approve`. Owner
   approval: the apply writes to the node.
5. Read the workload token with `task tf:pve-jarvis-output -- -raw token_value`.
   PVE returns the secret at creation. OpenTofu retains it in encrypted state.
   Copy it into `terraform/proxmox/jarvis/jarvis.local.auto.tfvars` as
   `pve_api_token = "terraform-prov@pve!tf=<secret>"`.
6. Prove the Terraform token by planning the workload root:
   `task tf:jarvis-plan`.
7. Retire an existing provisioning user's password on the node with
   `pveum passwd terraform-prov@pve`, as root.
   Enter a long random value. Discard the value.
   Skip this step for a new user created without a password.
8. Revoke the access-management token after the maintenance window.
   Issue a replacement before a later bootstrap plan, apply, or token rotation.
   Reading outputs needs the state credentials, not PVE authentication.

Tasks disable input prompts and fail if `pve_api_token` is missing.
OpenTofu omits this sensitive, ephemeral input from saved plans and state.
OpenTofu retains the created workload token in encrypted state for recovery.

## Upgrade an existing access root

The provider pin is `0.116.0`. Initialize before planning an existing root.
The access state uses the provider's short ACL and token names.
This root doesn't retain migration blocks.
For a snapshot with old names, follow Recovery before planning.
Stop if the plan replaces the token or destroys access resources.
The `prevent_destroy` guards stay enabled.

## Rotate the token

Get owner approval before rotating the token.

1. Lift `prevent_destroy` on the token resource in a reviewed commit.
2. Apply with `-replace="proxmox_user_token.tf"`.
3. Copy the new `token_value` into the jarvis tfvars.
4. Restore the guard.

Follow the same policy as [Rotate the S3 credential](rotate-s3-credential.md).

## Recovery

Restore a bucket state version or use the import blocks in `main.tf`.
The token secret is stored only in state and jarvis tfvars. Rotate it if both
copies are lost.

For a snapshot with old resource names, add temporary `moved` blocks in this
root before planning. Use these address mappings:

| From | To |
| --- | --- |
| `proxmox_virtual_environment_acl.terraform_provisioning` | `proxmox_acl.terraform_provisioning` |
| `proxmox_virtual_environment_user_token.tf` | `proxmox_user_token.tf` |

Expect state-address moves without token replacement.
Remove the temporary blocks after applying the state-only migration.

## Next steps

- [Provision an LXC workload with Terraform](provision-pve-ct.md): the root
  that consumes the token.
- [Add a Proxmox VE node](onboard-pve.md): copy this root for a second PVE
  server.
- [Terraform state design](../../terraform/BACKEND.md): the bucket, the
  guards, and the recovery path.
