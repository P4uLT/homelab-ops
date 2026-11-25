# systemd

Manage existing system services with `ansible.builtin.systemd_service`.
The inventory selects services. The role validates requests and applies them directly.
Request validation runs through `tasks/validate.yml` before service discovery and changes.

## Inputs

`systemd_services` defaults to `[]`, which skips fact gathering and service changes.
Each entry uses these fields:

| Field | Contract |
| ----- | -------- |
| `name` | Required complete name ending in `.service`, without paths or whitespace |
| `enabled` | Optional boolean. `true` enables startup at boot, and `false` disables it |
| `state` | Optional native state: `started`, `stopped`, `restarted`, or `reloaded` |
| `ignore_missing` | Optional boolean, default `false`. Skip the service when absent |

Each entry needs an action: `enabled` or `state`.
Omitted actions leave their settings unchanged. Omit `state` instead of passing null.
Enabling doesn't start a service. Disabling doesn't stop it.
Add `state` when the runtime state must change too.
Explicit restart and reload requests aren't idempotent.
Required missing services fail through the native module.
Explicitly optional services skip when absent or marked `not-found` in service facts.

## Examples

Enable or disable existing services at boot without changing their runtime state:

```yaml
systemd_services:
  - name: example.service
    enabled: true
  - name: another.service
    enabled: false
```

The container profile stops and disables its optional wait unit:

```yaml
container_service_units:
  - name: systemd-networkd-wait-online.service
    state: stopped
    enabled: false
    ignore_missing: true
```

Each consuming inventory declares that static policy. The caller binds it:

```yaml
- name: Apply the container service policy
  ansible.builtin.import_role:
    name: systemd
  vars:
    systemd_services: "{{ container_service_units }}"
```

## Boundaries

Services must already exist on a running systemd system.
The role doesn't install packages, create unit files, configure drop-ins, or mask services.
Privilege escalation belongs to the caller.
The server play uses `become: true`. The image connection already executes as root, without `sudo`.

Inputs use the local `apt` conventions for names, types, defaults, and inventory policy.
The tumf, cimon, and O1labs roles also render unit files. This role uses the
native module because it only manages existing services.

## Verification limits

Local argument checks, syntax, and lint don't prove live service behavior.
Get owner approval before applying or verifying service settings on managed hosts,
including repeated applies.
