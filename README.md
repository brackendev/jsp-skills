# jsp-skills

Jumpstart Pro Rails toolkit for multi-tenancy, billing, Hotwire, migrations, and deployment. Distributed as an APM plugin (`type: skill`) that installs into every runtime APM supports: Claude Code, Codex, OpenCode, Cursor, Copilot, Gemini, and Windsurf.

Source: <https://github.com/brackendev/jsp-skills>. APM shorthand: `brackendev/jsp-skills`.

## Installation

Project scope (writes into the consumer project):

```bash
cd /absolute/path/to/your-project
apm install brackendev/jsp-skills --target claude,codex,opencode,cursor,copilot,gemini,windsurf
```

User scope (writes under `~/`):

```bash
apm install brackendev/jsp-skills -g --target all
```

Update with `apm install --update [-g]`. Remove with `apm uninstall brackendev/jsp-skills [-g]`. A local filesystem path can replace the shorthand at either scope.

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

Pull Tier 2 updates into `jsp-fork-master`, merge to working branch, and create a PR.

```bash
/jsp-skills:sync
```

Conflict strategy:

| Category | Strategy |
|----------|----------|
| App code (`app/`, `test/`) | Keep Tier 3 |
| Infrastructure (`Makefile`, `Dockerfile`, `compose.yaml`) | Accept Tier 2 |
| `Gemfile` | Tier 2 base + Tier 3 gems |
| `config/database.yml`, `package.json` | Manual review |

### Auto-Triggered

These skills activate automatically based on conversation context.

| Skill | Triggers |
|-------|----------|
| `account-scoping` | "create model", "new controller", "add resource", "scaffold", "rails g model", "rails g controller", "rails g resource", "rails g scaffold", "generate model", "build controller", "background job" |
| `migration-safety` | "create migration", "add migration", "modify migration", "rails generate migration", "add column", "add index", "change table", "remove column", "schema change", "database migration" |
| `troubleshooting` | "Docker error", "container won't start", "SSL certificate", "make setup failed", "port already in use", "permission denied", "can't connect to database" |
| `tier2-sync` | "fork updates", "sync fork", "pull from fork", "tier 2 updates" |

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
