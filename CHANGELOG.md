# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0]

### Added

- Initial release as an APM plugin (`apm.yml`, `type: skill`) that installs into every runtime APM supports: Claude Code, Codex, OpenCode, Cursor, Copilot, Gemini, and Windsurf.
- Skills: `deploy-check`, `ship`, `sync`, plus auto-triggered `account-scoping`, `migration-safety`, `troubleshooting`, and `tier2-sync`.
- Specialist skills: `api-specialist`, `billing-specialist`, `database-specialist`, `deployment-specialist`, `hotwire-specialist`, `multi-tenancy-specialist`, `security-auditor`.
- Canonical skill source under `.apm/skills/`, with a `SKILL.md` mirror under `.opencode/skills/` for local OpenCode validation.
- Per-skill `agents/openai.yaml` metadata under `.apm/skills/<name>/agents/` for OpenAI runtime UI integration.
