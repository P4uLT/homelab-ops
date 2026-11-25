# image_bootstrap

Bootstrap the module interpreter and verify the expected Packer build container.

## Decision and scope

Use native `raw`, `setup`, and `assert` modules for image bootstrap and identity checks.
This role doesn't define population packages or general Python installation policy.

Packer and direct Ansible runs use `proxmox_pct_remote` with PVE `pct exec`.
The connection requires privileged access inside the Debian build container.
Call this role before content roles, with play-level fact gathering disabled.

## Interface

The [argument specifications](meta/argument_specs.yml) define the required input.
The caller binds Packer's container identifier to `image_bootstrap_vmid`.
The expected hostname is `builder-<identifier>`, matching the image builder's contract.

## Flow and checks

1. Probe `/usr/bin/python3` without requiring Python.
2. If missing, refresh the package index and install `python3` and `python3-apt`.
3. Gather facts, excluding device facts.
4. Require the hostname to match the expected build container.

The explicit `/bin/sh -c` keeps shell operators inside the container.
The connection plugin joins command arguments, so uncontained operators could run on the Proxmox hypervisor.
A connection failure remains a failure rather than becoming a successful missing-interpreter result.

If Python exists, the role skips installation without separately checking its apt bindings.
Identity verification follows bootstrap and precedes content provisioning.

## Verification

Use the caller's syntax check, production-profile lint, and `task verify`.
The raw bootstrap isn't a supported check-mode validation path.
Live bootstrap and a second apply require owner approval.
Offline command regressions don't prove that a real build container can be provisioned.
