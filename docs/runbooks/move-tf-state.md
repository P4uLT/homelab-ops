# Move Terraform code or state

A directory move doesn't move remote state.
Get owner approval before changing a backend location or contacting managed systems.

## Move code without moving state

1. Use `git mv` for the code move.
2. Keep the existing backend key.
   It can differ from the directory until an approved state migration.
3. Update relative module paths and partial backend paths.
4. Update the task root list.

## Migrate a backend location

1. Pause state writers.
2. Preserve the source state and any destination state.
3. Keep the passphrase and encryption configuration available.
4. Retain the old backend metadata for the approved `tofu init -migrate-state` operation.
5. Supply the destination's partial backend configuration.
6. Check the copied state.
7. Review a plan before applying infrastructure changes.

Don't let two roots manage the same resources.

`-reconfigure` selects a backend without copying state.
It doesn't replace a migration.
`-force-copy` accepts migration prompts automatically.
Don't use it to bypass destination-state review.
Resource `moved` blocks change addresses within state, not its bucket or object key.

## Related

- [Terraform state design](../../terraform/BACKEND.md#state-locations-and-code-moves)
- [Recover Terraform state](recover-tf-state.md)
