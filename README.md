# jsp-skills

[Jumpstart Pro Rails](https://jumpstartrails.com/) toolkit packaged as an [APM](https://github.com/microsoft/apm) plugin. One install deploys skills for multi-tenancy, billing, Hotwire, migrations, and deployment to every runtime APM supports: Claude Code, Codex, OpenCode, Cursor, Copilot, Gemini, and Windsurf.

Skills follow the [Agent Skills](https://agentskills.io) open standard. Two appear as slash commands (`/jsp-skills:sync-upstream`, `/jsp-skills:deploy-check`); the rest activate automatically from conversation context. Argument grammar, scope vocabulary, and the `--report` convention are documented in [CONVENTIONS.md](CONVENTIONS.md).

Source: <https://github.com/brackendev/jsp-skills>. APM shorthand: `brackendev/jsp-skills`.

## Install

This plugin is distributed through APM, so install [APM](https://github.com/microsoft/apm) first if you don't already have it. Then, in a project:

```bash
apm install brackendev/jsp-skills --target all
```

Globally for your user account:

```bash
apm install brackendev/jsp-skills -g --target all
```

Update with `apm update [-g]`. Remove with `apm uninstall brackendev/jsp-skills [-g]`. A local filesystem path can replace the shorthand at either scope.

## Quick start

Slash commands run inside your agent runtime (Claude Code, Codex CLI, OpenCode, and the rest), not at a shell prompt. The shell-styled code blocks below are formatted that way for readability.

Pull upstream changes from Jumpstart Pro Rails:

```bash
/jsp-skills:sync-upstream
```

Run pre-deployment checks before a production release:

```bash
/jsp-skills:deploy-check
```

The remaining skills (account scoping, migration safety, billing, Hotwire, and the rest) activate automatically when their domain comes up. They cannot be invoked directly.

## Skills

### User-invocable

#### `/jsp-skills:sync-upstream`

Mutating skill. Merge the latest Jumpstart Pro Rails upstream changes into a project that started from the Jumpstart Pro template. The skill's first priority is that project customizations are never silently overwritten.

Requires a Git remote named `jumpstart-pro` pointing at the Jumpstart Pro Rails repository. Add it with `git remote add jumpstart-pro <jsp-repo-url>` if it does not already exist.

What the skill does:

- Detects the project's primary branch and refuses to run with a dirty working tree.
- Displays the upstream `UPGRADE.md` before merging so upgrade notes are reviewed first.
- Computes the merge base, classifies every changed path as project-only, upstream-only, or both-changed, and surfaces the both-changed list before the merge.
- Wholesale-restores project-owned paths after the merge so customizations survive.
- Verifies a no-clobber invariant: every project-only path must be byte-identical to the project's `HEAD` before commit. If any were modified, the merge aborts.
- Writes a sync-audit report to `/tmp/jsp-sync-report.md` and stops after pushing the working branch. Open the pull request with your own workflow and paste the report under a `## Sync audit` section in the body.

Pass `--report` to produce the divergence audit only. The skill runs the fetch and classification steps, writes `/tmp/jsp-sync-report.md`, and stops before merging, committing, or pushing.

The full path policy and step-by-step procedure live in `.apm/skills/sync-upstream/SKILL.md`.

#### `/jsp-skills:deploy-check`

Pure report. Pre-deployment verification checklist before a production release.

### Auto-triggered

These activate from conversation context. They cannot be invoked directly.

| Skill | Triggers |
|-------|----------|
| `account-scoping` | "create model", "new controller", "add resource", "scaffold", "rails g model", "rails g controller", "rails g resource", "rails g scaffold", "generate model", "build controller", "background job" |
| `migration-safety` | "create migration", "add migration", "modify migration", "rails generate migration", "add column", "add index", "change table", "remove column", "schema change", "database migration" |
| `troubleshooting` | "Docker error", "container won't start", "SSL certificate", "make setup failed", "port already in use", "permission denied", "can't connect to database" |

### Specialists

Also auto-triggered. Specialists carry the deeper Jumpstart Pro patterns for each area and coordinate with each other (for example, `hotwire-specialist` defers database queries to `database-specialist` and account scoping to `multi-tenancy-specialist`).

| Skill | Activates on |
|-------|--------------|
| `api-specialist` | API endpoints, JWT authentication, OAuth flows, external API integrations, webhook handlers (non-payment) |
| `billing-specialist` | Subscriptions, payment processors (Stripe, Paddle, Braintree), payment webhooks, plan gating, per-seat pricing, one-time payments, dunning |
| `database-specialist` | Schema changes, migrations, indexes, multi-database configuration, database seeding, query performance, data integrity |
| `deployment-specialist` | Production deployments, server management, rollbacks, deployment troubleshooting, infrastructure configuration |
| `hotwire-specialist` | Turbo Frames/Streams, Stimulus controllers, TailwindCSS styling, View Components, Import Maps, interactive UI features |
| `multi-tenancy-specialist` | Account scoping, `Current.account` patterns, AccountRecord inheritance, Pundit policies, tenant isolation queries, account switching, impersonation |
| `security-auditor` | Security reviews, multi-tenancy isolation checks, authorization audits, sensitive data handling, Rails security best practices |

## Contributing

To work on the plugin source, see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
