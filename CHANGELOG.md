# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.30] - 2026-09-28

### Fixed

- The `billing-specialist` webhook examples used APIs that Pay 11 does not have. `Pay::WebhookExtension` overrode a `process` method and called `pay_customer`, and the dunning trigger read `request.env["pay.event"]` in an `after_action` on `Pay::Webhooks::StripeController`. Pay processes events in a background job, so neither ran. Both examples now subscribe listeners with `Pay::Webhooks.delegator.subscribe` inside `ActiveSupport.on_load(:pay)`, and the skill explains the order in which listeners run, the event object each processor passes, and how to avoid duplicating Pay's payment failed email.
- The skill told users to mount a nonexistent `Pay::Webhooks::Engine` in `config/routes.rb`. Pay mounts its engine automatically, and Jumpstart Pro sets the mount path to `/`.
- The skill said Pay deduplicates webhook events by event ID and told users not to add their own tracking. Pay stores no event ID and deletes each webhook record after processing it, so the skill now tells users to make custom listeners idempotent.
- The lists of events Pay handles included events Pay does not subscribe to, such as Stripe `invoice.payment_succeeded` and Paddle Billing `transaction.payment_failed`, and omitted others. The lists now match Pay 11, and the skill notes that Pay discards events without a listener.
- The webhook logging example hooked a nonexistent `Pay::Webhooks::BaseController` and passed keyword arguments to `Rails.logger.info`, which raises `ArgumentError`. It now adds the callback to each processor's controller and logs a formatted string.

## [0.1.29] - 2026-09-28

### Fixed

- The `deployment-specialist` skill used Kamal 1 commands and configuration that Kamal 2 removed. Jumpstart Pro uses Kamal 2. The skill configured Traefik labels and a `traefik:` section, ran `kamal traefik` commands, and checked `acme.json`. It now configures `proxy: ssl: true` with a `host`, troubleshoots certificates with `kamal proxy logs` and `kamal proxy reboot`, and notes that kamal-proxy's Let's Encrypt support works only with one server.
- The skill told users to run `kamal env push` after changing secrets. Kamal 2 writes each role's environment file when it boots the app, so the skill now says to redeploy.
- The migration pattern used `kamal deploy --skip-migrations`, which does not exist. The skill now explains that Jumpstart Pro's `bin/docker-entrypoint` runs `bin/rails db:prepare` when the web server boots, so every deploy migrates before the new container passes its health check, and migrations must stay backward compatible.
- The skill described `kamal deploy --skip-push` as a fresh build. The option skips the build and push and deploys an existing image.
- The skill used other commands and options that do not exist in Kamal 2 or fail there: `kamal doctor`, `kamal app versions`, `app logs --tail`, `--role=`, `rollback` without a version, `rails maintenance:enable`, and `docker` commands run through `kamal app exec`. They are replaced by `kamal config`, `kamal app containers`, `--lines`, `--roles=`, `rollback VERSION`, `kamal app maintenance` and `kamal app live`, `kamal prune all`, and SSH to the host. The `deploy-check` rollback step now passes a version as well.
- Secret checks ran `kamal config | grep`, which never matches because `kamal config` does not print the app environment. They now list secret names from `kamal secrets print` without printing values. The skill also no longer calls `.kamal/secrets` a file to keep out of version control. Jumpstart Pro commits it, so it must hold references rather than raw credentials.

## [0.1.28] - 2026-09-28

### Fixed

- The `deploy-check` credentials step ran `bin/rails credentials:show --environment production`, which printed every production secret into the terminal and the session transcript. The step now pipes the output through a filter that prints only each key name and whether its value is set.
- The `troubleshooting` fix for permission errors ran `chmod -R 777` on `log`, `tmp`, `app/assets/builds`, and `db`, making them world-writable. It now compares the host and container users, then either sets matching `UID` and `GID` values in `.env` and rebuilds, or restores ownership with `chown`.

## [0.1.27] - 2026-09-28

### Fixed

- The seven `*-specialist` skills did not set `user-invocable: false`, so Claude Code listed them in the `/` menu even though the documentation says they cannot be invoked directly. They now set the field, matching `account-scoping`, `migration-safety`, and `troubleshooting`. The model still activates them from conversation context.

## [0.1.26] - 2026-09-28

### Fixed

- The `multi-tenancy-specialist` and `security-specialist` skills described an `ImpersonationProtection` concern, an `impersonating?` helper, `Current.impersonator`, and a `session[:impersonating_user_id]` key as Jumpstart Pro features. Jumpstart Pro has none of these. It impersonates users with the `pretender` gem from Madmin, where `current_user` is the impersonated user and `true_user` is the admin. The skills now describe that flow and note that `require_current_account_admin` checks the impersonated user.
- The `billing-specialist` impersonation guard read `session[:impersonating]`, which nothing sets, so it never blocked anything. All three skills now use one application-level `ImpersonationGuard` concern that blocks the action when `current_user != true_user`, and explain how to add it to the Jumpstart Pro billing controllers. The logging and admin-target examples now override `Madmin::User::ImpersonatesController`.

## [0.1.25] - 2026-09-28

### Fixed

- The `multi-tenancy-specialist` roles section listed owner, admin, and member roles and called `current_account_user.owner?` and `admin_or_owner?`. Jumpstart Pro defines only `AccountUser::ROLES = [:admin]`, treats the owner as `Account#owner` rather than a role, and has no `current_account_user` helper. The section now describes the admin role, the owner, `Current.account_user`, `Current.account_admin?`, `Current.roles`, and the `require_current_account_admin` guard.
- The invitation example passed `roles: [AccountUser::MEMBER]`, which does not exist, and said the email was sent automatically through a Noticed notification. The example now sets the `admin` role flag and calls `save_and_send_invite`, which sends `AccountMailer#invite`. The key file paths now point to the `lib/jumpstart/` locations.

## [0.1.24] - 2026-09-28

### Fixed

- The `api-specialist` and `multi-tenancy-specialist` skills described a `SetCurrentAccount` concern that responds `:forbidden` for non-members, plus an `AccountScoped` concern and `rescue_from` handlers in `Api::BaseController`. Jumpstart Pro has none of these. Both skills now describe the actual stack: `Api::BaseController` includes `SetCurrentRequestDetails`, skips the fallback account, and sets `Current.account` from the prefixed `account_id` parameter through `current_user.accounts`. A missing or non-member ID leaves `current_account` nil.
- That lookup runs after the tenant is set, so `AccountRecord` queries in API actions are not tenant-scoped. The API examples and Common Pitfall 2 now return `:not_found` when `current_account` is nil and call `set_current_tenant(current_account)`. They no longer assign `Current.account_user`, which is a computed reader. The API Endpoints checklist reflects the same rules.

## [0.1.23] - 2026-09-28

### Fixed

- The `billing-specialist` skill called it critical to wrap Pay calls in `Current.set(account:)` and warned that calls without it "may leak data". Pay models are not tenant-scoped, and `Current.account` does not set the tenant, so the wrapper had no effect. The section now explains that Pay calls act on the account they are called on. It also explains that tenant context matters only for `AccountRecord` models, which need `ActsAsTenant.with_tenant` outside a request.
- The `billing-specialist` fulfillment example looked up the order from charge metadata before setting a tenant. Pay processes webhooks in a background job with no tenant, so the lookup could match any account's order. The example now sets the tenant from the charge's paying account and looks up the order inside that block.

## [0.1.22] - 2026-09-28

### Fixed

- The `multi-tenancy-specialist` skill described a `set_current_account` before_action that stored the account in `session[:account_id]`, and a `switch_account(account)` controller helper. Jumpstart Pro has neither. The request lifecycle section now describes `Jumpstart::AccountMiddleware` for path tenancy and the `SetCurrentRequestDetails` lookups (custom domain, subdomain, signed `account_id` cookie, then fallback account), followed by `set_current_tenant(Current.account)`. It also notes that the path, domain, and subdomain lookups do not check membership.
- The account switching section now describes `PATCH /accounts/:id/switch`, which writes a signed cookie, and the `switch_account_button` view helper. The controller and system test examples use the `switch_account` test helpers that Jumpstart Pro provides.
- The Action Cable example now matches Jumpstart Pro's `Connection`, which sets `current_account` in `connect`. Channels scope through that identifier and stream with `stream_for current_account` instead of trusting an account ID from subscription params, because the tenant is not set in channels.

## [0.1.21] - 2026-09-28

### Fixed

- The `multi-tenancy-specialist` skill said Jumpstart Pro sets `config.require_tenant = true`, and its console, rake task, API controller, fixture, and model test examples expected `ActsAsTenant::Errors::NoTenantSet`. Jumpstart Pro sets `config.require_tenant = false`, so a query without a tenant returns every account's rows instead of raising. The configuration section and examples now describe that behavior. The model test asserts that an unscoped query returns records from both accounts, and the fixture examples show the `ActiveRecord::NotNullViolation` that a missing `account` reference causes.

## [0.1.20] - 2026-09-28

### Fixed

- The `multi-tenancy-specialist`, `account-scoping`, `security-specialist`, `billing-specialist`, and `database-specialist` skills told the agent to use `Account::BaseJob` and `AccountRecord.with_account`, which Jumpstart Pro does not provide. They now use `ActsAsTenant.with_tenant(account)` with the account passed as a job argument. They also explain that `Current.account` is nil in a job, and that a job enqueued without a tenant returns every account's rows because Jumpstart Pro sets `config.require_tenant = false`.
- The `multi-tenancy-specialist` skill contradicted itself about job callbacks. Common Pitfall 5 and the checklists said `before_perform` runs before the parent's `around_perform` and sees no account. ActiveJob runs callbacks in declaration order, parent class first, so a subclass callback runs inside the parent's `around_perform`. The pitfall and checklists now say so.
- The `multi-tenancy-specialist` mailer example called `yield` from a `before_action`, which cannot wrap the action. It now uses `around_action`, and the mailer reads the account from `params` instead of `Current.account`, which is nil under `deliver_later`.
- The `database-specialist` and `migration-safety` data-migration examples set `Current.set(account:)` and described it as enabling `acts_as_tenant` scoping. Outside a request, `Current.account` does not set the tenant, so the examples now use `ActsAsTenant.with_tenant(account)`.

## [0.1.19] - 2026-09-28

### Fixed

- The `migration-safety`, `deploy-check`, and `troubleshooting` skills passed arguments to `make rails` and `make exec` through `ARGS="..."`. Those targets read their arguments from the command-line goals and ignore `ARGS`, so the commands stopped with "Error: Arguments required." The skills now use the goal form (`make rails db:rollback`, `make exec bundle audit`), which the other skills already used. `make logs` and `make build` still take `ARGS`.

## [0.1.18] - 2026-09-26

### Changed

- The `billing-specialist` skill no longer requires a fixed "Fetching Current Documentation" block before any code. It still asks for current processor and Pay gem documentation before processor-specific work, and it now names the current Context7 tools (`resolve-library-id`, then `query-docs`) instead of the retired `get-library-docs` call and its token parameter.
- The `account-scoping`, `migration-safety`, and `troubleshooting` descriptions describe the kinds of work that trigger them instead of listing individual phrases. The README trigger table matches.
- The `troubleshooting` skill no longer recommends `make clean` as the first step when the cause is unclear. It describes the full rebuild as destructive, asks the agent to diagnose first and confirm before running it, and asks a plain clarifying question instead of a scripted one.
- The specialist skills no longer carry trigger lists in their bodies or refer to themselves as agents, and the closing "guardian" statements are removed.

### Fixed

- The `billing-specialist` and `multi-tenancy-specialist` skills described the API as using JWT authentication. They now match `api-specialist`, which uses `ApiToken` mapped to Devise users.
- The `multi-tenancy-specialist` skill described `Api::BaseController` as skipping account resolution. It now matches `api-specialist`, where `SetCurrentAccount` sets `Current.account` from the nested route.
- The `deployment-specialist` skill listed `REDIS_URL` as a required variable and referred to a nonexistent `database-migration-manager` agent. It now lists the SolidQueue, SolidCache, and SolidCable database URLs and refers to the `database-specialist` and `migration-safety` skills.
- The `upstream-sync` skill now pre-approves `git rm` and `find`, which its merge and drift-detection steps run.
- The README no longer describes `/deploy-check` as a pure report, matching the skill description corrected in 0.1.14.

## [0.1.17] - 2026-09-16

### Changed

- The README's runtime sentence now names Grok Build after Kiro. APM 0.28.0 added `grok-build` as a canonical target that `apm install --target all` includes and that APM auto-detects from a `.grok/` directory, so the default target set now has nine runtimes. Grok Build keeps a target-native skill directory (`.grok/skills/` at project scope, `~/.grok/skills/` at user scope), like Claude Code and Kiro, rather than the shared `.agents/skills/` directory.

## [0.1.16] - 2026-07-29

### Changed

- The README's runtime sentence now scopes its list to APM's default target set rather than claiming every runtime APM supports. APM 0.26.0 also supports Antigravity, IntelliJ, and several experimental runtimes, none of which `apm install --target all` includes. The eight runtimes named are unchanged, and the sentence adds that Antigravity works when named explicitly with `--target antigravity`.

## [0.1.15] - 2026-07-29

### Removed

- The package manifest no longer declares the top-level `target: all` field. The APM manifest schema deprecates the `all` value: a parser treats the field as though it were absent and falls through to the `--target` flag or filesystem auto-detection, and the value is scheduled to become a hard parse error in a future APM release. Removing the field makes that fall-through behavior permanent. Installation behavior is unchanged, because APM already resolved targets by auto-detection rather than from this field. The separate `compilation.target` setting is not affected.

## [0.1.14] - 2026-07-08

### Fixed

- The `deploy-check` command description no longer claims it makes no changes. Step 1 runs `make verify`, which rebuilds the local environment and runs the full test suite, so the description now reflects that.
- The `account-scoping`, `migration-safety`, and `troubleshooting` skills had invalid YAML frontmatter caused by unescaped quotation marks in the `description`, which could prevent their metadata from loading under a strict parser. The descriptions are now correctly quoted.

## [0.1.13] - 2026-06-24

### Added

- The `README.md` documents the relationship to [37signals-skills](https://github.com/marckohlbrugge/37signals-skills) and recommends installing it as a companion. The new "Recommended companion" section explains that these skills focus on Jumpstart Pro specifics, that 37signals-skills supplies general Rails conventions, and that jsp-skills takes precedence inside a Jumpstart Pro application. It records the precedence order and the two divergences operators should know about: Jumpstart Pro authenticates with Devise rather than a custom Identity, Session, and User flow, and it relies on the Pay, Pundit, and acts_as_tenant gems rather than hand-written equivalents.

### Changed

- The `api-specialist`, `database-specialist`, `hotwire-specialist`, `migration-safety`, and `security-specialist` skills are re-scoped to Jumpstart Pro specifics. They no longer repeat general Rails technique (generic Turbo and Stimulus, REST and OAuth, PostgreSQL indexing and query optimization, and broad OWASP guidance) and defer it to a companion package. Each now states a precedence order and keeps a compact safety floor so standalone installs stay safe: staged migrations and concurrent indexes; authentication, authorization, tenant isolation, and cross-site request forgery protection; and webhook signature verification, idempotency, and replay handling.
- The `api-specialist`, `security-specialist`, `multi-tenancy-specialist`, and `billing-specialist` skills gain explicit callouts where Jumpstart Pro departs from general Rails conventions: authentication is Devise, tenant context is `Current.account` with `acts_as_tenant`, and billing runs through the Pay gem.
- The `account-scoping` skill is reduced to a fast generation checklist that defers the deeper multi-tenancy patterns to `multi-tenancy-specialist`. Its background-job example is corrected to place `account_id` first and wrap work in `AccountRecord.with_account`.
- The package description in `apm.yml`, the README introduction, and the per-skill OpenAI display descriptions are updated to reflect the Jumpstart Pro focus and the companion relationship.

## [0.1.12] - 2026-06-15

### Changed

- Add Kiro to the README's runtime list. APM 0.20.0 added Kiro as a first-class install target included in `apm install --target all`, so the README now lists it alongside Claude Code, Codex, OpenCode, Cursor, Copilot, Gemini, and Windsurf.

## [0.1.11] - 2026-05-28

### Added

- `CONVENTIONS.md` gains Rule 4: vendored and generated paths are excluded by default from mutating skills that walk the workspace. Two filters apply together (`.gitignore` matches plus a hardcoded floor of dependency directories, build outputs, and lock files). The override rides on Rule 1's existing `<path>` `<glob>` grammar; no new flag is introduced. The Author checklist gains a matching item. No skill in this plugin discovers candidate files from the workspace today: `/upstream-sync` is exempt because its target set is defined by upstream template reconciliation, and `/deploy-check` is a pure report. The rule is recorded so any future user-invocable mutating skill honors the same contract as its companion packages.

## [0.1.10] - 2026-05-28

### Changed

- The `upstream-sync` skill excludes `CLAUDE.md` and `AGENTS.md` from the merge result entirely. Previously these files were restored to the project version during the merge. Now `git rm` removes them unconditionally so neither the project version nor the upstream version survives. The step 8 divergence filter, step 15 no-clobber check, and step 16 divergence report are updated to reflect the new "excluded" treatment. The path policy table documents the change.

## [0.1.9] - 2026-05-26

### Fixed

- Quote the YAML `description` frontmatter in all skills that had unquoted values. Prevents potential YAML misinterpretation of special characters in description values.

## [0.1.8] - 2026-05-20

### Changed

- `CONTRIBUTING.md` is aligned to the family-wide structural template (Layout / APM lockfile rule / Adding or modifying a skill / Validation / Skill conventions). A `CONVENTIONS.md` row is added to the Layout table, the "Adding or modifying a skill" procedure now ends with an explicit version-bump step, and a new Skill conventions section documents the user-invocable / model-invocable distinction with package-specific example skills.

## [0.1.7] - 2026-05-20

### Changed

- The `sync-upstream` skill is renamed to `upstream-sync` to adopt the noun-first canonical naming pattern (`<target>-<verb>`) shared across the agent-skills family. Operators with a saved `/jsp-skills:sync-upstream` invocation should replace it with `/upstream-sync`. The OpenCode permission key and OpenAI runtime display name follow the rename.
- The `security-auditor` skill is renamed to `security-specialist` so the auto-triggered specialists share a consistent suffix (`api-specialist`, `billing-specialist`, `database-specialist`, `deployment-specialist`, `hotwire-specialist`, `multi-tenancy-specialist`, `security-specialist`). All sibling-skill cross-references are updated.
- Documented slash commands drop the `jsp-skills:` namespace prefix. The `README.md` quick-start, skill headings, and embedded usage examples now use bare slash commands (`/upstream-sync`, `/deploy-check`). The OpenCode permission keys in `opencode.jsonc` were already bare names; the change is documentation only for operators who invoke the skills from a slash menu.

## [0.1.6] - 2026-05-18

### Added

- `CONVENTIONS.md` documents how user-invocable skills receive arguments, declare scope, and choose between mutation and report behavior. New skills follow the three rules (argument grammar, scope vocabulary, mutation as the default), the classification taxonomy, the section-structure rules, and the author checklist in that file. `CONTRIBUTING.md` points to it as required reading for skill authors.

### Changed

- The `sync` skill is renamed to `sync-upstream`. Operators with saved invocations of `/jsp-skills:sync` should update them to `/jsp-skills:sync-upstream`. The OpenCode permission entry under `opencode.jsonc` and the OpenAI runtime display name follow the rename.
- The `sync-upstream` skill grows a `--report` flag. Default behavior continues to merge `jumpstart-pro/main`, run the divergence audit, commit, and push the working branch. With `--report`, the skill runs the fetch and classification steps, writes `/tmp/jsp-sync-report.md`, and stops before merging, committing, or pushing. Only the literal token `--report` triggers report mode; natural-language phrases such as `preview` or `dry run` are treated as scope input.
- The `deploy-check` skill description classifies it explicitly as a pure report. The skill's behavior is unchanged: it runs a fixed verification checklist and produces a go/no-go with evidence, making no changes to the project.

## [0.1.5] - 2026-05-18

### Changed

- `README.md` and `CONTRIBUTING.md` restructured for new-user onboarding. The README leads with a single install command, adds a quick-start section, and groups the skill catalog into User-invocable, Auto-triggered, and Specialists. The duplicated path policy table is removed from the README; the full policy continues to live in `.apm/skills/sync/SKILL.md`. `CONTRIBUTING.md` moves the file layout into a table, breaks out the APM lockfile rule into its own section, and adds an "Adding or modifying a skill" step list.
- The `api-specialist` and `billing-specialist` skills no longer hard-code Context7 as the only documentation source. The "Using Context7 for Current Documentation" sections are renamed to "Fetching current library documentation" and reworded so the model uses whichever documentation lookup the host runtime provides (Context7 MCP server, built-in web search, or a project-local source). Context7's `resolve-library-id` and `get-library-docs` calls remain as worked examples rather than required tools, so the skills work on every runtime APM targets, including those without Context7 installed.
- The `migration-safety` skill's reference to the JSP upstream agent guidelines file accepts both `CLAUDE.md` and `AGENTS.md` instead of naming only the Claude Code-conventional filename. The JSP template ships `CLAUDE.md`; project repositories may also expose it as `AGENTS.md` for runtimes that prefer that convention.

## [0.1.4] - 2026-05-14

### Changed

- The `sync` skill aligns with the upstream Jumpstart Pro Rails restructure of December 12, 2025. Upstream-owned framework source now lives under `lib/jumpstart/app/`, and the project's `app/` directory is the dedicated override layer. The path policy table adds a row for `lib/jumpstart/app/` and clarifies that upstream no longer adds files under `app/`. The dead "re-apply upstream additions under `app/`" block at the end of the project-owned policy step is removed.
- The `sync` skill adds a drift-detection step that runs after the divergence report is generated. The step inventories every project override under `app/` whose path mirrors a file under `lib/jumpstart/app/`, diffs each override against the post-merge upstream source, and appends a `### Project overrides with drift from upstream source` section to the sync audit report when drift is found.
- The `sync` skill documents a structural-first-then-reconcile cadence for handling deferred upstream improvements after the sync. Phase A creates overrides under `app/` and reverts engine-owned files in `lib/jumpstart/app/` to upstream HEAD as a single structural PR. Phase B reconciles override content against upstream improvements, one PR per area.

## [0.1.3] - 2026-05-14

### Changed

- The `sync` skill stops after pushing the working branch instead of opening a PR. The divergence audit is saved to `/tmp/jsp-sync-report.md`. The user opens the PR with their own preferred workflow and includes the report contents under a `## Sync audit` section in the PR body.

### Removed

- The `ship` skill. Project conventions for branch naming, PR template, screenshot capture, and labeling are no longer part of this plugin. Users open PRs with their own preferred workflow.

## [0.1.2] - 2026-05-14

### Changed

- The `sync` skill treats `AGENTS.md` the same as `CLAUDE.md`: project-owned, wholesale-restored to the project version after the merge, and surfaced in the upstream-additions section of the PR body when upstream introduces a new `AGENTS.md`.

## [0.1.1] - 2026-05-14

### Changed

- The `sync` skill is rewritten around a no-clobber guarantee. Project customizations are never silently overwritten. The skill computes the merge base between the project and `jumpstart-pro/main`, classifies every changed path as project-only, upstream-only, or both-changed, surfaces the both-changed list before the merge, and verifies a post-merge invariant that every project-only path is byte-identical to the project's `HEAD` before the merge commit is created. If the invariant fails, the merge aborts.
- The `sync` skill aligns with the Jumpstart Pro Rails upgrading convention. The remote is named `jumpstart-pro` (per https://jumpstartrails.com/docs/upgrading) and upstream changes are pulled from `jumpstart-pro/main`. The project's primary branch is detected dynamically via `git symbolic-ref refs/remotes/origin/HEAD`.
- The `sync` skill expands the project-owned path policy: `app/`, `test/` (including `test/seeds/`), `README.md`, `CLAUDE.md`, `.claude/`, `Makefile`, `compose.yaml`, `Dockerfile.dev`, `.github/`, `docs/`, `templates/`, `config/jumpstart.yml`, `Gemfile`, and `Gemfile.lock` are wholesale-restored to the project version after the merge. `.cursor/` and `UPGRADE.md` are treated as upstream-only artifacts; `UPGRADE.md` is displayed during sync so the maintainer can review upgrade guidance, and neither is copied into the project.
- The `sync` skill reverses the `Gemfile` strategy. The project's `Gemfile` is kept by default. Upstream gem additions and version changes are surfaced as a diff so the maintainer can opt in to specific changes instead of having to re-add project gems by hand. `Gemfile.lock` is regenerated locally after the merge commit.
- The `ship` skill includes a "Sync audit" section in the PR description when `sync` produces an audit report at `/tmp/jsp-sync-report.md`. The report includes counts of upstream-only, project-only, and both-changed paths, the both-changed list requiring review, and any upstream additions under project-owned paths that the maintainer may want to adopt in a follow-up.

### Removed

- The `tier2-sync` skill. Its keyword-based redirection to `/jsp-skills:sync` is no longer required because each project pulls directly from the JSP upstream remote.
- The post-merge `README-FORK.md` preservation step from the `sync` skill. With `README.md` project-owned, a committed copy of the upstream README would only create a stale artifact.
- Hardcoded references to the prior Tier 2 fork repository from the `account-scoping` and `troubleshooting` skills.

## [0.1.0] - 2026-05-10

### Added

- Initial release as an APM plugin (`apm.yml`, `type: skill`) that installs into every runtime APM supports: Claude Code, Codex, OpenCode, Cursor, Copilot, Gemini, and Windsurf.
- Skills: `deploy-check`, `ship`, `sync`, plus auto-triggered `account-scoping`, `migration-safety`, `troubleshooting`, and `tier2-sync`.
- Specialist skills: `api-specialist`, `billing-specialist`, `database-specialist`, `deployment-specialist`, `hotwire-specialist`, `multi-tenancy-specialist`, `security-auditor`.
- Canonical skill source under `.apm/skills/`, with a `SKILL.md` mirror under `.opencode/skills/` for local OpenCode validation.
- Per-skill `agents/openai.yaml` metadata under `.apm/skills/<name>/agents/` for OpenAI runtime UI integration.
