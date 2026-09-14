# Documentation

Everything in this directory describes the repository as it works now. Start
here.

## Reference

- [Writing rules](writing.md): how we write docs, the eleven published rules,
  the tooling, and where each rule comes from.
- [SOPS and age procedures](sops.md): encrypt, decrypt, back up the key,
  recover a fresh clone.
- [SSH key and host-key practices](ssh.md): which key belongs where, how to
  pin a host key, what to rotate and when.
- [OVH object storage conventions](object-storage.md): bucket per data class,
  one access boundary each.
- [OVH least privilege](ovh-least-privilege.md): why the bootstrap credential
  is broad, and what replaces it.

## Runbooks

[Runbooks](runbooks/README.md) hold the operational procedures: onboard a PVE
node, bootstrap the state backend, build a golden image, provision a container.

## Where the rest lives

- [Terraform state design](../terraform/BACKEND.md): backend layout, keys,
  recovery.
- [Repository layout and commands](../README.md)
- [Agent instructions](../AGENTS.md): hard rules, gotchas, project structure.
