# jsp-skills

Jumpstart Pro Rails toolkit for multi-tenancy, billing, Hotwire, migrations, and deployment. Distributed as an APM plugin (`type: skill`) that installs into every runtime APM supports: Claude Code, Codex, OpenCode, Cursor, Copilot, Gemini, and Windsurf.

Source: <https://github.com/brackendev/jsp-skills>. APM shorthand: `brackendev/jsp-skills`.

## Installation

Project scope (writes into the consumer project):

```bash
cd /absolute/path/to/your-project
apm install brackendev/jsp-skills --target all
```

User scope (writes under `~/`):

```bash
apm install brackendev/jsp-skills -g --target all
```

Refresh dependencies with `apm update [-g]`. Remove with `apm uninstall brackendev/jsp-skills [-g]`. A local filesystem path can replace the shorthand at either scope.

See [WORKFLOWS.md](WORKFLOWS.md) for real-world skill sequences.

## Skills

All skills follow the [Agent Skills](https://agentskills.io) open standard. Skill source lives under `.apm/skills/<name>/SKILL.md`, with a `SKILL.md` mirror under `.opencode/skills/<name>/` for local OpenCode validation.

### User-Invocable

Trigger explicitly with `/jsp-skills:<name>` (or `$<name>` in runtimes that use that prefix).

#### `deploy-check`

Pre-deployment verification checklist before production release.

```bash
/jsp-skills:deploy-check
```

#### `ship [issue-number] [pr-title]`

Branch, commit, push, create PR, and label in one workflow.

```bash
/jsp-skills:ship 161 Add SSL troubleshooting guide   # with issue and title
/jsp-skills:ship 161                                 # with issue (generates title)
/jsp-skills:ship                                     # generates everything
```

#### `sync`

Merge Jumpstart Pro Rails (JSP) upstream changes into the project on a working branch and open a PR. The project repository must have the JSP repository configured as a Git remote named `jumpstart-pro`.

```bash
/jsp-skills:sync
```

The skill's first priority is that project customizations are never silently overwritten. To deliver that guarantee it:

- Detects the project's primary branch and refuses to run with a dirty working tree.
- Displays the upstream `UPGRADE.md` before merging so the maintainer reviews upgrade notes first.
- Computes the merge base between the project and `jumpstart-pro/main`, then classifies every changed path as project-only, upstream-only, or both-changed. The both-changed list is shown before the merge so the maintainer knows which files Git will auto-merge.
- Applies a project-owned policy that wholesale-restores explicit paths to the project version after the merge.
- Verifies a no-clobber invariant before commit: every project-only path must be byte-identical to the project's `HEAD`. If any project-only path was modified, the merge aborts.
- Writes a markdown sync-audit report that `/jsp-skills:ship` embeds in the PR description.

Path policy:

| Path | Treatment |
|------|-----------|
| `app/` | Project owns; new upstream files under `app/` flow in |
| `test/` (including `test/seeds/`) | Project owns |
| `README.md`, `CLAUDE.md`, `.claude/` | Project owns |
| `Makefile`, `compose.yaml`, `Dockerfile.dev`, `.github/` | Project owns |
| `docs/`, `templates/` | Project owns |
| `config/jumpstart.yml` | Project owns |
| `Gemfile` | Project version kept; upstream gem changes surfaced for opt-in |
| `Gemfile.lock` | Project version kept; regenerate with `bundle lock` after the merge commit |
| `.cursor/`, `UPGRADE.md` | Upstream-only; `UPGRADE.md` is displayed during sync, neither is copied into the project |
| `config/database.yml`, `package.json` | Manual review during conflict resolution |
| Rails substrate (`config/` other than above, `db/`, `lib/`, `bin/`, root dotfiles, `Rakefile`, anything else) | Divergence audit: project changes preserved, upstream changes applied, both-changed paths reported for review |

### Auto-Triggered

These skills activate automatically based on conversation context.

| Skill | Triggers |
|-------|----------|
| `account-scoping` | "create model", "new controller", "add resource", "scaffold", "rails g model", "rails g controller", "rails g resource", "rails g scaffold", "generate model", "build controller", "background job" |
| `migration-safety` | "create migration", "add migration", "modify migration", "rails generate migration", "add column", "add index", "change table", "remove column", "schema change", "database migration" |
| `troubleshooting` | "Docker error", "container won't start", "SSL certificate", "make setup failed", "port already in use", "permission denied", "can't connect to database" |

### Specialists

These skills activate automatically when their domain comes up. They carry the deeper Jumpstart Pro patterns for each area.

| Skill | Activates on |
|-------|--------------|
| `api-specialist` | API endpoints, JWT authentication, OAuth flows, external API integrations, webhook handlers (non-payment) |
| `billing-specialist` | Subscriptions, payment processors (Stripe, Paddle, Braintree), payment webhooks, plan gating, per-seat pricing, one-time payments, dunning |
| `database-specialist` | Schema changes, migrations, indexes, multi-database configuration, database seeding, query performance, data integrity |
| `deployment-specialist` | Production deployments, server management, rollbacks, deployment troubleshooting, infrastructure configuration |
| `hotwire-specialist` | Turbo Frames/Streams, Stimulus controllers, TailwindCSS styling, View Components, Import Maps, interactive UI features |
| `multi-tenancy-specialist` | Account scoping, `Current.account` patterns, AccountRecord inheritance, Pundit policies, tenant isolation queries, account switching, impersonation |
| `security-auditor` | Security reviews, multi-tenancy isolation checks, authorization audits, sensitive data handling, Rails security best practices |

Skills coordinate with each other: for example, the `hotwire-specialist` skill defers database queries to `database-specialist` and account scoping to `multi-tenancy-specialist`.

Working on the plugin source: see [CONTRIBUTING.md](CONTRIBUTING.md).
