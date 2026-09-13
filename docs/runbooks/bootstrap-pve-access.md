# Bootstrap the PVE access of the Terraform roots

The `terraform/bootstrap/pve/jarvis/` root owns the whole access chain
Terraform uses on the node jarvis: the role, the group, the user
`terraform-prov@pve`, the ACL on `/`, and the API token. Nothing
Ansible declares anymore. The root is frozen: it runs once, every
resource carries `prevent_destroy`, and any change is a reviewed
commit.

The root authenticates as the minting account, `root@pam` by default.
That password is the one-time minting credential. It lives only in the
root's git-ignored `jarvis.local.auto.tfvars`, next to the endpoint.

The state is remote, on the shared bucket, key `jarvis-access`.
Unlike `bootstrap/ovh`, there is no circularity: the bucket predates
this root, so the state, which holds the token value, is versioned and
covered by the recovery kit.

## First run

1. Create `terraform/bootstrap/pve/jarvis/jarvis.local.auto.tfvars`
   from its `.example`, mode 600, with the endpoint and the minting
   account password.
2. Plan: `mise exec -- task tf:pve-jarvis-plan`. The plan imports the
   existing role, group, user, and ACL (Ansible created them until
   now), creates the token, and shows one expected normalization: the
   group comment cleanup.
3. Apply: `mise exec -- task tf:pve-jarvis-apply -- -auto-approve`.
   Owner approval: the apply writes to the node.
4. Read the mint: `mise exec -- task tf:pve-jarvis-output -- -raw
   token_value`. The value prints once, at creation. Copy it into
   `terraform/proxmox/jarvis/jarvis.local.auto.tfvars` as
   `pve_api_token = "terraform-prov@pve!tf=<secret>"`. This is the
   same flow as the S3 keys of the OVH bootstrap.
5. Prove the credential: `mise exec -- task tf:jarvis-plan`, or the
   oper play `credential_check.yml`.
6. Retire the password, one time on the node, as root:
   `pveum user modify terraform-prov@pve --password` and enter a long
   random value nobody records. The user is token-only from then on,
   and the leaked-password rotation debt is closed.

## Rotate the token

Lift `prevent_destroy` on the token resource in a reviewed commit,
apply with `-replace="proxmox_virtual_environment_user_token.tf"`, copy
the new `token_value` into the jarvis tfvars, then restore the guard.
The same policy as the S3 credential rotation of `bootstrap/ovh`.

## Recovery

Restore the state object version from the bucket, or import the
objects again with the import blocks in `main.tf`. The token value
only lives in the state and in the jarvis tfvars; a lost value means a
rotation.
