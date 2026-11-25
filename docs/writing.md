# Writing rules

Documentation rules and checks. To reuse these rules elsewhere, omit
[In this repository](#in-this-repository).

## Organize content by reader task

Choose content for the reader's task:

| | Acquisition | Application |
| --- | --- | --- |
| **Action** | Tutorial: learn a skill | How-to: complete a task |
| **Cognition** | Explanation: understand a topic | Reference: look up details |

Separate content when different reader tasks interfere. Orientation pages can introduce and link to several document types.
Use task titles for how-to pages, such as `Rotate the S3 credential`, and topic titles for explanations.

## Prose

`task docs:check` enforces these twelve rules for repository Markdown.
Code comments use the same rules except `Acronyms` and `Vale.Terms`, because
identifiers can resemble prose.

| Rule | Requirement |
| --- | --- |
| No spaced em dash | Use a colon, parentheses, a comma, or a period |
| Contractions | `don't`, `isn't`, `can't` |
| No semicolons | Split the sentence |
| Timeless | Describe current behavior, not when it changed |
| No excessive claims | Avoid `best`, `simplest`, `fastest`, `never`, and `always`. Support claims with measurements |
| No Latin abbreviations | `for example`, not `e.g.` |
| American spelling | `color`, not `colour` |
| No anthropomorphism | Describe operations without human abilities |
| Unfamiliar acronyms | Spell out the first use or add a vocabulary entry |
| Exact domain-term casing | `PVE`, not `pve` |
| At most 25 words per sentence | Keep one idea per sentence |
| Tool names without a mise prefix | `packer fmt`, `uv run ansible-lint` |

Add domain terms to `.vale/styles/config/vocabularies/House/accept.txt`, one
expression per line, following [host terminology](../AGENTS.md#host-terminology).
Don't disable a rule for a missing vocabulary entry.

Also apply these editorial rules:

- Use plain words and active voice. State who does what.
- Put conditions before instructions, with one action per step.
- Use the serial comma in lists of three or more.
- Keep error strings verbatim in backticks.
- Remove filler such as `just`, `really`, `basically`, and `simply`.
- Keep paths and technical names exact.
- Use sentence-case headings without final periods.

## Lifecycle

- Update documentation in the same commit as a behavior change.
- Fix incorrect pages and delete obsolete ones.
- Keep one source for each fact and link to it instead of duplicating it.
- Link pages from their parent.

## Tooling

### Skills

| Skill | Use |
| --- | --- |
| [`docs-sync`](../.agents/skills/docs-sync/SKILL.md) | Sync docs with repository facts, page ownership, and operational safeguards |
| `docs-editor` (global installation) | Portable editing with bundled structure, concision, clarity, and editorial rules |

### Checks

| Command | Purpose |
| --- | --- |
| `task docs:check` | Check repository prose against the writing rules |
| `task verify` | Run the full local checks, including prose and links |
| `vale --config=.vale.ini path/to/file.md` | Check one file |
| `task docs:links` | Check internal links and anchors offline |
| `task docs:links-external` | Check outbound links over the network |

The generic editor lives in `~/.agents/skills/docs-editor/`, outside this repository's checks.
Keep its bundled license notices with the package.

Without the mise shell hook, run `mise exec -- task verify`.
`House.NoMisePrefix` rejects this prefix in files except `AGENTS.md` and this page.
Vale returns nonzero for `error` alerts, not warnings.

### Setting the check up elsewhere

Copy the pins from `mise.toml`, `.vale.ini`, and `.vale/` for an offline Vale
report without `vale sync`.

## Provenance

Use published standards. Record reasons for local deviations beside the choice.

| Source | Contributes |
| --- | --- |
| [Google developer style](https://developers.google.com/style) | Prose rules, measured claims, timeless documentation |
| [Microsoft Writing Style Guide](https://learn.microsoft.com/en-us/style-guide/welcome/) | Brevity, contractions, conditions before instructions |
| [ASD-STE100](https://www.asd-ste100.org/) | One instruction per sentence, one word per meaning, no semicolons |
| [Diátaxis](https://diataxis.fr/) | Content organized around reader needs |
| [Chromium documentation practices](https://chromium.googlesource.com/chromium/src/+/main/docs/documentation_best_practices.md) | Maintain docs with code, remove duplication, archive design decisions |
| [Write the Docs](https://www.writethedocs.org/guide/writing/docs-principles/) | Link rather than copy, repeat information when needed for the reader |

## In this repository

`docs/runbooks/` contains how-to pages. `docs/` also includes reference and
explanation. `docs/superpowers/` contains ignored planning archives, not
maintained documentation.

Vale doesn't read `.gitignore`, so checks use `git ls-files` to exclude ignored
vendor content and environments such as `ansible/.venv` and `.terraform`.

## Related

- [Agent instructions](../AGENTS.md)
- [Documentation index](README.md)
