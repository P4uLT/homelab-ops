# Bootstrap the PVE access of the Terraform roots

The `terraform/bootstrap/pve/jarvis/` root owns the whole access chain
Terraform uses on the node jarvis. That chain is the role, the group, the
user `terraform-prov@pve`, the ACL on `/`, and the API token.
Ansible doesn't manage these objects. The root is frozen: it runs once, every resource carries
`prevent_destroy`, and any change is a reviewed commit.

The root authenticates with a separate access-management API token.
You issue that token outside this root, before running it.
Keep it in this root's git-ignored `jarvis.local.auto.tfvars`, next to the
endpoint. The provider doesn't use password authentication or SSH.

The state is remote, on the shared bucket, at
`bootstrap/pve/jarvis/terraform.tfstate`. Unlike `bootstrap/ovh`, there is no
circularity: the bucket predates this root. Versioning and the recovery kit
cover the state, which holds the token value.

## Issue the access-management token

Get owner approval before changing PVE permissions or issuing the token.
Use the PVE interface at Datacenter > Permissions with an administrator account.

1. Add a role named `Terraform_AccessBootstrap` with these privileges:

   ```text
   Group.Allocate Permissions.Modify Realm.AllocateUser Sys.Audit Sys.Modify User.Modify
   ```

2. Add an API token for `root@pam` with token ID `terraform-bootstrap`.
   Keep Privilege Separation enabled and set an expiration for the maintenance window.
3. Copy the secret shown at creation into the local file described below.
4. Add an API token permission on `/` for `root@pam!terraform-bootstrap`.
   Select `Terraform_AccessBootstrap` and enable propagation.

The role manages groups, PVE users, roles, ACLs, and user tokens.
`Permissions.Modify` on `/` can grant cluster-wide permissions.
Treat this token as an administrative credential, not a workload credential.
These operations use the API and don't require the account password in OpenTofu.
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
   For an existing file, add `pve_api_token` and remove `pve_username` and
   `pve_password`. The root no longer declares those password inputs.
   Set the token as `root@pam!terraform-bootstrap=<secret>`.
   Replace `<secret>` with the value copied at creation.
   Don't overwrite the workload root's local file.
2. Initialize the roots with `task tf:init`.
   This reads the remote state backend, not the PVE node.
3. Plan with `task tf:pve-jarvis-plan`.
   On the first run, review the imports for the existing role, group, user,
   and ACL. The plan creates the workload token if it isn't in state.
   For an existing root, review the address moves described below.
4. Apply: `task tf:pve-jarvis-apply -- -auto-approve`. Owner
   approval: the apply writes to the node.
5. Read the workload token with `task tf:pve-jarvis-output -- -raw token_value`.
   PVE returns the secret at creation. OpenTofu retains it in encrypted state.
   Copy it into `terraform/proxmox/jarvis/jarvis.local.auto.tfvars` as
   `pve_api_token = "terraform-prov@pve!tf=<secret>"`. This is the same flow as
   the S3 keys of the OVH bootstrap.
6. Prove the Terraform token by planning the workload root:
   `task tf:jarvis-plan`.
7. Retire an existing provisioning user's password on the node with
   `pveum passwd terraform-prov@pve`, as root.
   Enter a long random value nobody records.
   Skip this step for a new user created without a password.
8. Revoke the access-management token after the maintenance window.
   Issue a replacement before a later bootstrap plan, apply, or token rotation.
   Reading outputs needs the state credentials, not PVE authentication.

The tasks disable input prompts. A missing `pve_api_token` fails instead of
asking for a password. The token input is sensitive and ephemeral, so
OpenTofu omits it from saved plans and state.
The minted workload token remains in encrypted state for recovery.

## Upgrade an existing access root

The provider pin is `0.116.0`. Initialize before planning an existing root.
The access state uses the provider's short ACL and token names.
This root doesn't retain migration blocks.
For a snapshot with old names, follow Recovery before planning.
Stop if the plan replaces the token or destroys access resources.
The `prevent_destroy` guards stay enabled.

## Rotate the token

Lift `prevent_destroy` on the token resource in a reviewed commit, apply with
`-replace="proxmox_user_token.tf"`, copy the new
`token_value` into the jarvis tfvars, then restore the guard. The same policy
as [Rotate the S3 credential](rotate-s3-credential.md).

## Recovery

Restore the state object version from the bucket, or import the objects again
with the import blocks in `main.tf`. The token value lives only in the state
and in the jarvis tfvars. A lost value means a rotation.

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
