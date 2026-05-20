# Skill Conventions

This document is the canonical source for how skills in this plugin receive arguments, declare scope, and produce reports versus mutations. A reader who learns one skill should be able to predict every other skill. New skills follow this document.

The rules apply to user-invocable skills under `.apm/skills/`. Skills that are not user-invocable (the auto-triggered checklists and specialists in this plugin: `account-scoping`, `migration-safety`, `troubleshooting`, and the `*-specialist` family) carry no argument surface and are exempt from rules 1 and 2.

## Rule 1: argument grammar

User-invocable skills accept natural-language keywords and bare paths. The single sanctioned flag is `--report`. No other `--name` flags are introduced for new skills.

Scope and option keywords are bare words:

- `all`, `<path>`, `<glob>`: scope keywords
- Skill-specific modifiers are expressed as ordinary phrases (`agents only`, `keep completed`, `lint and test`), not as POSIX flags.

Skills interpret these inputs naturally. The skill's Arguments table lists the recognized inputs and the effect of each. Operators do not need to memorize POSIX flag syntax to use a skill.

An author who needs a flag for a skill-specific behavior beyond `--report` documents the exemption in the skill's `SKILL.md` and explains why a bare keyword does not work.

## Rule 2: scope vocabulary

Skills that operate on files, diffs, pull requests, or commit messages use the same scope vocabulary. The vocabulary has a core that applies whenever the skill supports the concept, plus opt-in rows that individual skills declare only when they genuinely understand the input. Adding unsupported rows to every skill would make the convention look cleaner while making the skill's own help less truthful.

### Core scope rows

Every file-aware skill uses these rows in its Arguments table:

| Input             | Target                                                     |
|-------------------|------------------------------------------------------------|
| (no argument)     | The skill's narrowest useful default                       |
| `all`             | Widen the selected scope to its maximum                    |
| `<path>` `<glob>` | Operate on those files or directories                      |

The rows compose. Their effects in combination are:

| Combination          | Effect                                                       |
|----------------------|--------------------------------------------------------------|
| (no argument)        | Narrow default applied to the whole command                  |
| `all`                | Maximum scope applied to the whole command                   |
| `<path>`             | Narrow default applied within that path                      |
| `<path> all`         | Maximum scope applied within that path                       |

The narrow default and the maximum are both per-skill: each skill defines what they mean in concrete terms (changed lines, changed files, whole file, full project, the entire upstream merge) directly in its Arguments table. The keyword's job is identical across every skill: `all` widens. The unit varies because each skill operates on a different artifact.

Some skills have no narrower default than their maximum scope. In that case `all` is accepted as a no-op input for family consistency. The Arguments table shows the two rows producing the same effect so an operator reading the table sees the skill's behavior, not a missing row.

Each skill documents the fallback for `(no argument)` when there is no git worktree, no changed lines, or no default context to derive. Common fallbacks are to ask the operator for explicit scope or to stop and report no targets.

### Opt-in scope rows

A skill adds these rows to its Arguments table only when it supports the input. Skills that do not understand pull requests or commit messages leave the rows out rather than declaring them as no-ops.

| Input             | Target                                                     |
|-------------------|------------------------------------------------------------|
| `#N` or PR URL    | That pull request                                          |
| `pr`              | Current branch's pull request title and body               |
| `commit`          | Most recent commit message plus staged draft               |

The `commit` row combines committed state (`git log -1 --pretty=%B`) with staged state (the contents of `.git/COMMIT_EDITMSG` when present). The combination is deliberate so an operator can run a voice or quality pass over a draft before committing, but the skill records both sources in its report so the operator knows which lines come from where.

### Skills without file scope

A skill that does not operate on a file or diff scope does not carry a scope table at all. `deploy-check` in this plugin falls in this category: its work is a fixed verification checklist over the project and the local environment, not over a per-invocation scope.

## Rule 3: mutation is the default; `--report` opts into reporting

A skill that can mutate the workspace applies its changes when invoked. The operator passes `--report` to receive a description of what the skill would do without modifying any files.

Naming reinforces the default. Commands follow a noun-first `<target>-<verb>` pattern, so the trailing verb signals behavior. Mutating commands carry verb suffixes that imply change (`-sync`, `-fix`, `-prune`, `-rebuild`, `-deploy`, `-new`, `-upgrade`, `-test`, `-create`, `-apply`); in this package, `/upstream-sync`. Operators who type a `*-sync` command expect the skill to sync. Pure-report skills carry reading-verb suffixes (`-review`, `-audit`, `-check`); in this package, `/deploy-check`.

- Default (no `--report`): apply the skill's recommended changes. Stop on unfixable failures the same way the skill always did.
- `--report` produces a description of what the skill would change, with the same evidence and findings the default run would generate. The skill writes no files, runs no formatters in write mode, and creates no external state under `--report`. Pre-existing scratch artifacts the skill always produces (for example, `/tmp/jsp-sync-*` audit files) are still written because they are the report.

### Only the literal token

Only the exact token `--report` enables the report-only mode. Natural-language phrases such as "describe the changes" or "show me what would happen" are scope or focus input, not a mode trigger. An operator who types `/upstream-sync report` receives a scope-narrowed mutation run, not a report. An operator who types `/upstream-sync --report` receives the description and nothing else changes on disk.

This rule exists to prevent accidental report-mode invocation that an operator expected to mutate.

## Skill classification

Every user-invocable skill falls into one of two categories. The category determines whether the skill needs a `--report` flag.

### Mutating skills

Mutation is the default. They may carry a `--report` flag when a preview mode is genuinely useful for the workflow.

| Skill             | `--report` available? | Notes                                                                                                  |
|-------------------|------------------------|--------------------------------------------------------------------------------------------------------|
| `/upstream-sync`  | Yes                    | Merges upstream and pushes a working branch by default. `--report` produces the divergence audit only. |

### Pure reports

The skill never mutates the project. It has no `--report` flag because there is nothing to invert.

| Skill            | Notes                                                                                                            |
|------------------|------------------------------------------------------------------------------------------------------------------|
| `/deploy-check`  | Runs a fixed pre-deployment checklist over the project and local environment. Produces a go/no-go with evidence. |

A skill is classified by its actual behavior, not by its name. The classification appears in the skill's own description so the operator knows what to expect.

## Section structure

Every user-invocable skill that takes arguments uses these headings in this order, omitting the ones that do not apply:

1. `## Arguments`: the argument grammar table, including scope rows and (when applicable) the `--report` row.
2. `## Scope`: include only when the scope vocabulary needs detection order, fallback behavior, or base-branch resolution beyond what the Arguments table can express in one row.
3. `## Mutation`: include only when the mutation behavior needs clarification beyond a single table row.

`## Customization` is retired as a section name.

A skill with no argument surface (such as `/deploy-check`) does not carry a `## Arguments` section. Its description states the classification ("pure report") so an operator can predict the behavior from the catalog entry alone.

## Worked example: upstream-sync

`/upstream-sync` mutates by default. It operates on a single fixed target (the configured `jumpstart-pro` remote merged into the project's primary branch), so the `<path>`/`<glob>` and `all` rows in the core scope vocabulary are accepted as no-ops for family consistency. The skill genuinely understands the `--report` row.

```markdown
## Arguments

| Input             | Effect                                                                 |
|-------------------|------------------------------------------------------------------------|
| (no argument)     | Merge `jumpstart-pro/main` into the project, run the divergence audit, push the working branch |
| `all`             | Same as no argument. Accepted for family consistency.                  |
| `<path>` `<glob>` | Same as no argument. The merge spans the whole repository; per-path scope is not meaningful. Accepted for family consistency. |
| `--report`        | Run the divergence audit only. Write `/tmp/jsp-sync-report.md` and stop before the merge. No worktree changes, no commit, no push. |
```

The default applies the merge, the project-owned policy, the conflict resolution, and the push. `--report` substitutes a fetch-and-classify pass that stops after the pre-merge audit (step 10 in the skill body) and writes the report file.

## Worked example: deploy-check

`/deploy-check` is a pure report. It carries no argument surface and no `## Arguments` section. Its description states the classification:

```markdown
---
name: deploy-check
description: Pre-deployment verification checklist before production release. Pure report: produces a go/no-go with evidence. Makes no changes to the project.
allowed-tools: Read, Bash
user-invocable: true
disable-model-invocation: true
---
```

## Ambiguity notes

These edge cases are real and skills must address them explicitly.

### `(no argument)` outside a git worktree

The default of `(no argument)` is "changed lines in tracked files" for skills that take a diff scope. A skill invoked outside a git worktree has no diff to derive scope from. Each skill defines the fallback. Common fallbacks:

- Ask the operator for explicit scope.
- Operate on the entire default target.
- Stop and report that no targets were found.

`/upstream-sync` does not derive scope from a diff and does not need this fallback, but it does refuse to run outside a git worktree (and outside a worktree with the `jumpstart-pro` remote configured) for unrelated reasons. The skill's body documents that refusal.

### `all` widens; the unit varies

`all` has a single meaning across skills: widen the selected scope to the maximum the skill operates on. The concrete unit varies because each skill inspects a different artifact. The operator-facing action is identical everywhere: omit the argument for the narrow default, add `all` for the broadest mutation or execution. Each skill states its concrete maximum in the Arguments table row.

### `--report` versus natural-language synonyms

`--report` is the only mode-toggle token. `dry run`, `report`, `preview`, and similar words used without the leading dashes are scope or focus input, not mode triggers. Skills explicitly reject natural-language mode-toggle attempts. An operator who wants the report-only mode must pass the literal token `--report`.

## Author checklist

Before merging a new or modified user-invocable skill, the author confirms:

- The skill's frontmatter declares `user-invocable` correctly and `disable-model-invocation` matches the intended invocation style.
- If the skill takes arguments, it has a `## Arguments` section. `## Customization` is not used.
- File-aware skills include the three core scope rows in the Arguments table.
- Opt-in scope rows (`#N`, `pr`, `commit`) appear only when the skill supports them.
- The skill is classified explicitly as a mutating skill or a pure report in its description.
- Mutating skills that benefit from a preview mode include a `--report` row in the Arguments table and apply changes only when the literal token is absent.
- The command verb implies the default behavior. A skill named `/sync-*`, `/fix-*`, `/commit`, `/prune-*`, or `/rebuild-*` should mutate by default; the name promises action. A skill named `/*-check` or other report-suggestive names should not mutate the project.
- The mirror at `.opencode/skills/<name>/SKILL.md` is byte-identical to `.apm/skills/<name>/SKILL.md`.
- The frontmatter `name` field matches the skill's directory name in both the canonical source and the mirror.
- `CHANGELOG.md` records the change under `[Unreleased]` when the change is user-facing.
