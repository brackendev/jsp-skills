# jsp-skills

Jumpstart Pro Rails toolkit for multi-tenancy, billing, Hotwire, migrations, and deployment. Built on the [Agent Skills](https://agentskills.io) open standard.

## Installation

### Claude Code

```bash
/plugin marketplace add brackendev/jsp-skills
/plugin install jsp-skills@jsp-skills
```

To uninstall:

```bash
/plugin uninstall jsp-skills@jsp-skills
/plugin marketplace remove brackendev/jsp-skills
```

### Other Agent Skills-compatible tools

These skills follow the [Agent Skills](https://agentskills.io) open standard. Compatible tools include [OpenCode](https://opencode.ai), [Cursor](https://www.cursor.com), [Gemini CLI](https://github.com/google-gemini/gemini-cli), and others that support the `.claude/skills/` path.

Clone the repository and symlink skill directories from `jsp-skills/skills/` into the skills directory for your tool.

See [WORKFLOWS.md](WORKFLOWS.md) for real-world skill sequences.

## Skills

All skills follow the [Agent Skills](https://agentskills.io) open standard.

### `/jsp-skills:deploy-check`

**Does:** Pre-deployment verification checklist before production release.

**Produces:** Pass/fail report

```bash
/jsp-skills:deploy-check                    # full verification
```

### `/jsp-skills:ship [issue-number] [pr-title]`

**Does:** Branch, commit, push, create PR, and label in one workflow.

**Produces:** Push + PR

```bash
/jsp-skills:ship 161 Add SSL troubleshooting guide   # with issue + title
/jsp-skills:ship 161                                 # with issue (generates title)
/jsp-skills:ship                                     # generates everything
```

### `/jsp-skills:sync`

**Does:** Pull Tier 2 updates into jsp-fork-master, merge to working branch, and create PR.

**Produces:** Merged branch + PR

**Conflict Resolution:**
| Category | Strategy |
|----------|----------|
| App code (app/, test/) | Keep Tier 3 |
| Infrastructure (Makefile, Dockerfile, compose.yaml) | Accept Tier 2 |
| Gemfile | Tier 2 base + Tier 3 gems |
| config/database.yml, package.json | Manual review |

```bash
/jsp-skills:sync                            # pull, resolve conflicts, create PR
```

### Auto-Triggered

These skills activate automatically based on conversation context.

| Skill | Triggers |
|-------|----------|
| **account-scoping** | "create model", "new controller", "add resource", "scaffold", "rails g model", "rails g controller", "rails g resource", "rails g scaffold", "generate model", "build controller", "background job" |
| **migration-safety** | "create migration", "add migration", "modify migration", "rails generate migration", "add column", "add index", "change table", "remove column", "schema change", "database migration" |
| **troubleshooting** | "Docker error", "container won't start", "SSL certificate", "make setup failed", "port already in use", "permission denied", "can't connect to database" |
| **tier2-sync** | "fork updates", "sync fork", "pull from fork", "tier 2 updates", `/jsp-skills:sync` |

## Agents (Claude Code)

Agents activate automatically based on task context.

| Agent | Triggers |
|-------|----------|
| **api-specialist** | API endpoints, JWT authentication, OAuth flows, external API integrations, webhook handlers (non-payment) |
| **billing-specialist** | Subscriptions, payment processors (Stripe, Paddle, Braintree), payment webhooks, plan gating, per-seat pricing, one-time payments, dunning |
| **database-specialist** | Schema changes, migrations, indexes, multi-database configuration, database seeding, query performance, data integrity |
| **deployment-specialist** | Production deployments, server management, rollbacks, deployment troubleshooting, infrastructure configuration |
| **hotwire-specialist** | Turbo Frames/Streams, Stimulus controllers, TailwindCSS styling, View Components, Import Maps, interactive UI features |
| **multi-tenancy-specialist** | Account scoping, Current.account patterns, AccountRecord inheritance, Pundit policies, tenant isolation queries, account switching, impersonation |
| **security-auditor** | Security reviews, multi-tenancy isolation checks, authorization audits, sensitive data handling, Rails security best practices |

Agents coordinate with each other. For example, `hotwire-specialist` defers database queries to `database-specialist` and account scoping to `multi-tenancy-specialist`.
