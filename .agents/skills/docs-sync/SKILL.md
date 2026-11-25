---
name: docs-sync
description: Syncs this repository's documentation with code and operational policy. Use when asked to "update the docs", "review stale docs", or shorten documentation after a change. For editorial methods use docs-editor; for agent instructions or skill files use agents-md or agent-skills-creator.
---

# Docs sync

- **IS:** syncing this repository's documentation with current source facts, page ownership, and operational safeguards.
- **Out of scope:** generic editorial guidance (`docs-editor`), agent-instruction editing (`agents-md`), and skill authoring (`agent-skills-creator`).

Apply the [writing rules](../../../docs/writing.md).
Load `docs-editor` by name for writing, structure, concision, and clarity.
The repository rules take precedence over its general guidance.
If the skill isn't discoverable, report that and use the writing rules without claiming the full editorial workflow.

## Page ownership

Keep each fact on its canonical page and link to it elsewhere.

| Page | Content |
| --- | --- |
| `README.md` | Orientation, install, quickstart, components |
| `AGENTS.md` | Agent instructions |
| `ansible/README.md` | Ansible layout, populations, services, verification |
| `packer/README.md` | Image inheritance, contents, provisioning |
| `terraform/README.md` | OpenTofu roots and editor setup |
| `terraform/BACKEND.md` | State design and recovery-kit requirements |
| `docs/README.md` | Documentation index |
| `docs/writing.md` | Writing rules and sources |
| `docs/runbooks/*` | Procedures |
| `docs/sops.md`, `docs/object-storage.md`, `docs/ssh.md`, `docs/ovh-least-privilege.md` | Domain references |

`docs/superpowers/` contains ignored planning archives, not live documentation. Leave those records unchanged.

## Update the pages

1. Use the requested paths. If none are specified, identify the canonical page in the table and start there. Include a linked procedure or reference when the change affects it. Preserve staged and working edits.
2. For code-driven updates, list the changed facts, then search old and new names, paths, and terms across tracked files. Include taskfiles, inventory, and comments. Exclude vendor content and `docs/superpowers/`. Read each hit in context. Check the canonical pages even when a search finds no matches.
3. For review-only requests, report findings and proposed corrections without editing. For updates or authorized rewrites, check facts against source evidence, then use `docs-editor` for the relevant editorial work. Reuse canonical pages before adding new ones. Keep safety conditions beside the actions they constrain.
4. Compare edits with the source and original text. Check commands, flags, defaults, prerequisites, approval requirements, recovery paths, errors, links, and attribution.
5. Search for obsolete names and verify replacement names, paths, and anchors.

Don't add tooling without the owner's request. A green check doesn't replace correcting stale or misleading content.

## Verify and report

Use focused checks while editing. Before reporting completion, run the required full local proof from the repository root:

```sh
task docs:check
task docs:links
task verify
```

`task verify` includes the first two checks. These tasks select tracked files. Check each untracked page directly with the relevant command. Don't stage a page only to make a task discover it.

Fix failures caused by the edits. Don't add suppressions to hide real findings. Never run a host-contacting procedure just to validate its documentation. Get owner approval before any host contact, including Ansible check mode.

For shortening requests, compare before and after word counts using the same method. Exclude fenced code and link URLs, and report the actual reduction without a target. For factual updates, report corrections and necessary additions instead of forcing a reduction.

Report changed paths, the main correction, checks and outcomes, and any unverified operation. Include a short before/after example when it clarifies a substantial rewrite. Leave commit and push decisions to the owner.

## Gotchas

- Ansible check mode can change a node. Treat a runbook's check-mode command as a host operation, not as a harmless documentation test.
- `task docs:check` and `task docs:links` read tracked paths. A new untracked page is skipped unless you check it directly.
