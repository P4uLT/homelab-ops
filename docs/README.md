# Documentation

Everything in this directory describes the repository as it works now. Start
here.

## Reference

- [SOPS and age procedures](sops.md) — encrypt, decrypt, back up the key,
  recover a fresh clone.
- [SSH key and host-key practices](ssh.md) — which key belongs where, how to
  pin a host key, what to rotate and when.
- [OVH object storage conventions](object-storage.md) — bucket per data class,
  one access boundary each.

## Runbooks

[Runbooks](runbooks/README.md) hold the operational procedures: onboard a PVE
node, bootstrap the state backend, build a golden image, provision a container.

## Where the rest lives

- [Terraform state design](../terraform/BACKEND.md) — backend layout, keys,
  recovery.
- [Repository layout and commands](../README.md)
- [Agent instructions](../AGENTS.md) — hard rules, gotchas, project structure.
