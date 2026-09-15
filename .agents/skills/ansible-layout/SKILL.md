---
name: ansible-layout
description: Decide where an Ansible play, layer, or file belongs, and how the playbook tree is shaped. Use when adding a playbook or a layer, when a change could live in several places, or when the tree stops being readable.
---

# Ansible layout

- **In scope:** the shape of the playbook tree. Tracks, layers, routers, and
  where content belongs.
- **Out of scope:** role internals. That's `ansible-roles`.

## Two tracks, for one hard reason

A build track and a fleet track, each with its own entry point and its own
inventory. The reason isn't tidiness. The build seals an artifact, and that
step wipes the machine identity. If the fleet entry point could reach it, one
mistaken host limit would destroy a live machine. The split makes the
destructive play unreachable, and neither a tag nor a filter can promise that.

## A layer is a directory behind a router

A layer holds one file per concern, and an `all.yml` router imports them in
order. Each file is a play, or a sub-router when the concern has steps. The
payoff: a topic is found by its name, and it runs alone.

Split when finding a topic means reading the file, or when a topic is run and
changed on its own. Split a directory when it holds steps, so the category
router names the thing rather than one of its steps.

Keep a check as one file. It runs as one command, and a router over two checks
adds navigation without helping anyone.

## Name each layer for its audience

Every layer answers one question: who receives this. The same word must mean
the same thing in both tracks. A word that means two things reads as
consistency while it hides a contradiction, and that's the fault that costs
the most to unpick.

- the base of a track. The artifact in one, the platform of the hosts in the
  other.
- the additions a host opts into.
- a whole application, in the build track only, because it changes the
  artifact.
- the wiring of one population, which belongs to a service, opt-in by group.

## The inventory is the exclusion

A play names a group. A host that must not receive it stays out of that group.
Never a guard in the code that skips a family of hosts. A skip is silent. A
group that nothing joins is a group that nothing joins, and you can see it.

The corollary: a family group that everything receives is a trap. The day a
machine of another kind joins it, the play reaches the wrong host. A host that
belongs nowhere is just as bad, and nothing reports it.

## One implementation, many callers

A role serves the build track and the fleet track, so a clone and a host run
the same code. The values live in the inventory of each track, under the names
the caller expects. Call the vendor directly. A wrapper that asserts and
imports earns nothing, and `ansible-roles` says why.

## Traps that cost a fix

- **A file or directory name that matches a public schema.** A file named
  `inventory.yml` is read as an inventory, and a directory named `profiles`
  collects editor errors. Rename it, or keep the path out of the scans.
- **`when: x is defined`.** A typo disables the work in silence. Let the
  inventory declare a value, and let the role carry a default.
- **An assert written as a list.** `x is defined` followed by
  `x | length > 0` raises a template error on the first, so the failure
  message never shows. Write one condition with a default filter.
- **`no`, `yes`, `on`, and `off` unquoted are booleans**, in a flow list too.
- **A comment is prose.** The prose gate lints comments in YAML like anywhere
  else.

## Proof without touching a machine

A host limit is the selection, so a typo skips a play in silence.
`--list-hosts` shows what a playbook would reach, offline, on any change. Use
it after every move.

Then run the shell's own gates. The linter at its strict profile, and the
syntax pass. A local connection for an inventory check, and a check-mode run
before anything that changes state.

## The loop

1. Name the layer by its audience, and the file by its topic.
2. Write the reference first, so the tooling covers it.
3. Move one thing at a time, and prove the targeting with `--list-hosts`.
4. Update the page that owns the layout, then run the gates before claiming
   the work is done.
