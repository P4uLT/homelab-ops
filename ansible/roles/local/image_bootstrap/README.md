# image_bootstrap

Bootstrap the module interpreter and verify the expected Packer build container.

## Decision and scope

Keep the existing image capability, using native `raw`, `setup`, and `assert` modules.
Interpreter bootstrap alone doesn't cover its `pct` shell boundaries and builder identity check.
This role isn't population package policy or a general Python installation role.

The target is a Debian build container reached through `proxmox_pct_remote`.
The connection must provide privileged access inside that container.
Call this role before content roles, with play-level fact gathering disabled.

## Interface

The required input is declared in [argument specifications](meta/argument_specs.yml).
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

An existing interpreter skips installation. The role doesn't separately verify its apt bindings.
The identity check runs after bootstrap, before content provisioning.

## Verification

Use the caller's syntax check, production-profile lint, and `task verify`.
The raw bootstrap isn't a supported check-mode validation path.
Live bootstrap and a second apply require owner approval.
Offline command regressions don't prove that a real build container can be provisioned.
