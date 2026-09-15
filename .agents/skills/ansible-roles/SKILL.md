---
name: ansible-roles
description: Audit, write, or review an Ansible role against the standard shape and the project's conventions. Use when adding a role, auditing a vendor role, or reviewing role variables, defaults, or metadata.
---

# Ansible roles

- **In scope:** one role. Does it earn a directory, how does it declare its
  knobs, and how does the caller reach it.
- **Out of scope:** playbook layout, inventory design, secrets handling.

## The gate: does the role earn a directory

A local role exists only when the need is **specific** and **no valid
alternative exists**. Try this order, and stop at the first that fits.

1. **The builtin module.** A need that reduces to a few parameters of `apt`,
   `systemd_service`, `user`, or `copy` is answered by the module itself. A
   role over it adds a dispatch layer, not a capability. ansible-core
   maintains the module, so it stays current with the distribution.
2. **A vendor role**, pinned exactly, audited with the table below.
3. **A local role.** Write it last, and make it do work.

A role whose body is an assert plus an `import_role` is a wrapper for nothing.
It earns no directory. Call the vendor at the call site, and let its own
variable names carry the values.

## Auditing a vendor role

Run every check. One failure is enough to reject.

| Check | How to see it | A failure that costs a fix |
| ----- | ------------- | -------------------------- |
| Last commit | `git log -1 --format=%ci` on the clone | a role frozen for years |
| Removed modules | grep for `apt_key`, `apt_repository` | `apt_key` is gone from recent ansible-core |
| Modern formats | grep for `deb822` and `.sources` | no deb822 on a current target |
| Declared platforms | `meta/main.yml` | releases from a decade ago |
| Maintenance signal | CI, releases, issue activity | a dead badge and nothing since |
| Standalone use | README, `ansible_local` facts, template macros | a role that needs its framework around it |
| Licence | the LICENSE file | a licence that clashes with the project |
| Fork cost | what a fix would touch | rewriting the parts nobody uses |

The surface that rots is the surface nobody uses. A role that manages keys,
repositories, and proxies to serve a three-parameter need is a liability. A
role assembled from several dead roles is dead on arrival.

## The standard shape

| Path | Rule |
| ---- | ---- |
| `tasks/main.yml` | The work. Purpose lives in the header comment, short, stating the why. |
| `defaults/main.yml` | Every knob, with its conservative value. Named with the role prefix. |
| `meta/main.yml` | Minimal `galaxy_info`, plus `dependencies: []`. |
| `meta/argument_specs.yml` | Every option: `type`, `description`, and `choices` or `required`. |
| `files/` | Only when the role ships a file. |
| `handlers/`, `vars/`, `templates/` | Only when used. An empty one is clutter. |
| `README.md` | Usually none. The header comment and the defaults document the role. |

`ansible-lint` enforces the prefix: a variable declared in a role must start
with the role name. The rule fires once the role declares its defaults, so a
role without defaults hides the problem.

## Declaring the knobs

- **Defaults, never magic.** A variable the role reads but never declares is
  undiscoverable. Declare it.
- **Conservative default.** Anything that moves a machine's state aggressively
  defaults to off. An upgrade mode defaults to `'no'`, not `safe`.
- **Required means required.** An argument that must come from the caller goes
  in `argument_specs.yml` with `required: true`. Never an empty default plus an
  assert, which is two mechanisms for one check.
- **Declare the choices.** A `choices` list turns a typo into a failure before
  the first task runs.
- **No opt-in by variable presence.** `when: users_to_create is defined`
  disables a role on a typo, and nothing says so. Either the caller declares a
  value, or the role carries a default.
- **An assert carries logic.** It checks a fact or a computed condition, and
  its message says how to fix the problem. It never restates a presence check
  that `argument_specs` owns.

## Naming

- A role name states its machine assumption, not its position. A container
  unit and a package policy are two roles, because one machine takes the first
  and never the second.
- A profile that means nothing on a machine stays out of that machine's play.
  The inventory decides, not a guard in the code.
- Use the project's documented vocabulary, in the project's language. Pull the
  word from the documentation, not from memory.

## What not to do

- **One role for every machine.** A play that targets a whole host family
  reaches machines it shouldn't. A machine outside the family gets nothing in
  silence. Both failures stay invisible until something breaks.
- **A table of roles in a variable.** A list that dispatches roles hides the
  decision in the data. A play names its group and its roles.
- **A multi-distribution matrix for a single-distribution need.** The matrix
  is the part that rots.

## Traps that cost a fix

- **`no`, `yes`, `on`, and `off` unquoted are booleans.** `apt_upgrade: no` is
  `False`, and a guard that compares it to the string `'no'` runs the upgrade
  anyway. Quote it. It bites inside a flow list too: `choices: [no, safe]`
  parses as `[False, 'safe']`, and validation then rejects `'no'`.
- **The prose gate lints comments.** A role comment fails on `it is`, on
  `cannot`, and on a sentence past 25 words, like any other prose.
- **Write the reference before the role.** A linter doesn't see an unreferenced
  role, so nothing checks it until a play calls it.

## The loop

1. Decide the shape: builtin, vendor, or local role. Write the reference in the
   playbook first.
2. Write the role: `defaults/`, `meta/argument_specs.yml`, `meta/main.yml`,
   `tasks/`.
3. Run `ansible-lint` at the production profile.
4. Run the syntax check, then the project's full gate before claiming the work
   is done.
5. A second run changes nothing. `changed=0` is the idempotence proof.
