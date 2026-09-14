---
name: docs-sync
description: Resync this repository's tracked docs with the code after a change. Use when a rename, move, or structural change landed, when asked to update, sync, or review the docs, or when a doc claim looks stale. Starts from the changed facts, greps the old vocabulary everywhere, and proves the result with the gates.
---

# Docs sync

- **In scope:** bringing tracked documentation back in line with the code
  after a change. Finding stale claims, fixing them, deleting the dead ones.
- **Out of scope:** writing a new page from scratch, or changing the prose
  rules. Those live in `docs/writing.md`. Planning history is frozen, see the
  map.

## The map

Each fact has one owning page. When a fact moves, fix the owner and delete
the copies instead of re-asserting them elsewhere.

| Page | Owns |
| ---- | ---- |
| `README.md` | Orientation, install, quickstart, what's inside |
| `AGENTS.md` | Agent guidance: commands, task layout, hard rules, gotchas, style |
| `ansible/README.md` | The Ansible shell: layout, populations, services, verify |
| `packer/README.md` | The Packer shell: image chain, contents, provisioning route |
| `terraform/README.md` | The OpenTofu roots and the editor setup |
| `terraform/BACKEND.md` | State backend design and recovery |
| `docs/README.md` | The documentation index |
| `docs/writing.md` | The prose rules and the source of each rule |
| `docs/runbooks/*` | One runnable procedure per file, steps only |
| `docs/sops.md`, `docs/object-storage.md`, `docs/ssh.md`, `docs/ovh-least-privilege.md` | Their named domain |

`docs/superpowers/` is git-ignored planning history. Never rewrite it to
match reality. Record a divergence in the spec's status section instead.

## The loop

1. List what changed as facts: renames, moves, new files, new tasks, changed
   commands, changed defaults. One line each.
2. Turn each fact into grep patterns: the old path (`playbooks/servers`), the
   old name (`grp_docker`), the old vocabulary (`spoke`), the removed file
   (`docker_service.yml`).
3. Grep every pattern across the tracked tree, excluding `docs/superpowers`
   and vendor directories. Taskfiles, inventory, and code comments rot too,
   not only `docs/`.
4. Read every hit with its context. Fix the claim, or delete it when the
   fact is gone. Don't patch the word and leave the claim wrong.
5. Grep the new vocabulary as well. A claim can be stale without naming the
   old world, like a procedure that still points at a file that moved.
6. Check the map: every page that owns a changed fact.
7. Stage deletions, then run `task docs:check` while iterating, and
   `task verify` before claiming done.

## Rules that bite

`task docs:check` runs Vale on `git ls-files`, and it fails the run on any
error. The rules that actually fire here:

- Sentences stay under 25 words. Split, don't trim.
- Contractions are required: "don't", "can't". A verbatim error string keeps
  its long form, in backticks.
- No semicolons or em dashes in Markdown.
- No anthropomorphism. Vale rejects human qualities in software. Write "the
  value is visible" instead of a sentence about what a reader does with it.
- Comments inside code files are linted too: playbook headers, HCL blocks,
  taskfile comments.

## Gotchas

- `task docs:check` lints `git ls-files`. A deleted but unstaged file kills
  it with a missing-argument error. Stage deletions before running any
  gate.
- A check-mode or plan task that contacts a host needs owner approval, and
  so does any doc procedure that describes one. Keep the approval wording
  when editing a runbook.
- AGENTS.md takes at most one new gotcha per pull request, and only for a
  mistake it prevented. A sync isn't a gotcha generator.
- Renames in prose are found by grepping the old word everywhere, then by
  reading the files that use the new word. Both passes, or the review is
  half-blind.

## Where the work ends

The greps come back clean, the gates are green, the changes are staged, and
the report names each stale claim that was fixed or deleted. Anything left
open goes to the owner, in the report, not silently.
