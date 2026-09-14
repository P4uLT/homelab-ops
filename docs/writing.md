# Writing rules

How this repository writes documentation, and the tooling that enforces it.
Every rule traces to a published source, so a reviewer can point at the source
instead of at taste.

The page travels. Everything except [In this repository](#in-this-repository)
applies to any project. Drop that section when you copy the rest.

## One type per file

Every page is exactly one Diátaxis type. Classify with the compass: does the
content serve action or cognition, and is the reader acquiring a skill or
applying one?

| | Acquisition | Application |
| --- | --- | --- |
| **Action** | Tutorial: a lesson | How-to: a task for a competent reader |
| **Cognition** | Explanation: context and alternatives | Reference: neutral description |

A page that answers differently for different sections is two pages. Name a
how-to after its task, as `Rotate the S3 credential` does. Name an explanation
with an implicit "About".

## Prose

Ten rules, each one published, all enforced by `task docs:check`. `.vale.ini`
enables exactly these ten.

| Rule | Says |
| --- | --- |
| No spaced em dash | A colon after a term, parentheses, or a comma inside a sentence. Or two sentences |
| Contractions | `don't`, `isn't`, `can't`. A contraction costs one word where the full form costs two |
| No semicolons | Split the sentence |
| Timeless | State how it works, not when it changed |
| No excessive claims | No `best`, `simplest`, `fastest`, `never`, `always`. Measure instead |
| No Latin abbreviations | `for example`, not `e.g.` |
| American spelling | `color`, not `colour` |
| No anthropomorphism | Software returns, rejects, stores. It doesn't see or tell |
| Spell out an unfamiliar acronym | On first use, or add the term to the vocabulary |
| Exact casing for a domain term | `PVE`, not `pve`. The vocabulary is the list |

The vocabulary lives in `.vale/styles/config/vocabularies/House/accept.txt`, one
expression per line. It follows the Host terminology section of
[Agent instructions](../AGENTS.md). Add a domain term there rather than
silencing a rule.

The rest is judgment, and no linter checks it:

- Plain words: `use`, not `utilize`. `start`, not `initiate`.
- Active voice, present tense. Name the actor.
- Conditions before instructions. Put the prerequisite before the step.
- One instruction per sentence in a procedure. One action per step.
- Serial comma in a list of three or more.
- A verbatim error string keeps its exact text, in backticks. Never contract a
  message the reader will search for.
- Cut filler: `just`, `really`, `basically`, `simply`.
- Name the file, the command, the field. Keep exact paths and exact names.
- Sentence case in headings. No period at the end of a heading.

## Lifecycle

Four rules that decide whether a page exists at all:

- **Ship docs with the change.** A behavior change and its documentation land
  in the same commit.
- **Delete dead documentation.** A page for a feature that no longer exists
  misinforms with authority. Delete it rather than leaving it to rot.
- **Link, don't copy.** When a concept lives in another page, link to it. Two
  copies drift apart and the reader can't tell which wins.
- **Every page gets a link.** A page with no inbound link is undiscoverable.
  Index it from its parent.

An incorrect page is worse than a missing one. That's the test to apply to
every page: if a reader following it lands somewhere wrong, fix it or delete
it.

## Tooling

### Skills

Three skills carry these rules into an agent session. Load the one that
matches the moment.

| Skill | Use it for |
| --- | --- |
| `terse` | Anything written: chat, memory, commits, comments |
| `docs-writing` | A documentation page: type gating, structure, hygiene |
| `asd-ste100` | Text a machine parses: tool descriptions, error messages, agent instructions |

Skills that govern other artifacts (agent instruction files, READMEs,
diagrams, publishing) stay out of this page: they don't write the prose these
rules govern.

### Checks

| Command | Does |
| --- | --- |
| `task docs:check` | The ten prose rules, over every tracked Markdown file |
| `task verify` | Everything, `docs:check` included |
| `mise exec -- vale --config=.vale.ini <path>` | The same rules on one path while you write |

Vale fails a run on an `error` alert only. A rule left at the `suggestion`
level it ships with reports findings and still exits 0, so `.vale.ini` raises
every enabled rule to `error`. A report that can't fail isn't a gate.

### Setting the check up elsewhere

Copy four things into the other repository: the `vale` pin from `mise.toml`,
`.vale.ini`, `.vale/styles/Google/`, and the vocabulary folder
`.vale/styles/config/vocabularies/`. No `vale sync` runs, so the check works
offline from the first clone.

## Provenance

Adopt the published standard rather than a local preference, and record the
reason next to a choice that isn't standard.

| Source | Contributes |
| --- | --- |
| [Google developer documentation style guide](https://developers.google.com/style) | The eight prose rules, excessive claims, timeless documentation |
| [Microsoft Writing Style Guide](https://learn.microsoft.com/en-us/style-guide/) | Brevity, contractions, conditions before instructions |
| [ASD-STE100](https://www.asd-ste100.org/) | One instruction per sentence, one word per meaning, no semicolons |
| [Diátaxis](https://diataxis.fr/) | One type per file |
| [Chromium documentation best practices](https://chromium.googlesource.com/chromium/src/+/main/docs/documentation_best_practices.md) | Delete dead documentation, duplication is evil, design docs are archives |
| [Write the Docs](https://www.writethedocs.org/guide/writing/docs-principles/) | Link instead of copy, accept some repetition for the reader |

## In this repository

Where the types live here: `docs/runbooks/` holds the how-to pages, `docs/`
holds reference and explanation, and `docs/superpowers/` holds frozen planning
records that aren't documentation.

The check scans tracked files through `git ls-files`, so the ignored trees
(`ansible/.venv`, `.terraform`) stay out of it. Vale doesn't read `.gitignore`
itself, so a plain scan reads all 170 Markdown files of the working tree,
vendored ones included.

Nothing in this section travels.

## Related

- [Agent instructions](../AGENTS.md): the hard rules, the gotchas, the layout.
- [Documentation index](README.md): what lives where.
