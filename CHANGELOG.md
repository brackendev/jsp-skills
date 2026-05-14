# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

## [0.1.0]

### Added

- Initial release as an APM plugin (`apm.yml`, `type: skill`) that installs into every runtime APM supports: Claude Code, Codex, OpenCode, Cursor, Copilot, Gemini, and Windsurf.
- Skills: `deploy-check`, `ship`, `sync`, plus auto-triggered `account-scoping`, `migration-safety`, `troubleshooting`, and `tier2-sync`.
- Specialist skills: `api-specialist`, `billing-specialist`, `database-specialist`, `deployment-specialist`, `hotwire-specialist`, `multi-tenancy-specialist`, `security-auditor`.
- Canonical skill source under `.apm/skills/`, with a `SKILL.md` mirror under `.opencode/skills/` for local OpenCode validation.
- Per-skill `agents/openai.yaml` metadata under `.apm/skills/<name>/agents/` for OpenAI runtime UI integration.
