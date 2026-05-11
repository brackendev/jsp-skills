# Contributing

This file is for people working on the plugin source. End-user install instructions live in [README.md](README.md).

## Layout

- `apm.yml`: package manifest (`type: skill`, no MCP dependencies).
- `.apm/skills/`: canonical skill source. APM deploys from here. Each skill directory holds `SKILL.md` plus optional supporting files (`agents/openai.yaml` for OpenAI runtime metadata, `references/`, `scripts/`, `examples/`).
- `.opencode/skills/`: `SKILL.md` mirror of `.apm/skills/`. Used for local OpenCode validation (`opencode --pure debug skill`). Only `SKILL.md` is mirrored; supporting files under `.apm/skills/<name>/agents/` are not duplicated.
- `opencode.jsonc`, `.opencode/package.json`: local OpenCode configuration files.
- `README.md`: end-user documentation.
- `WORKFLOWS.md`: real-world skill sequences.
- `CHANGELOG.md`: user-facing changes per version.
- `CLAUDE.md`: local working notes (gitignored globally).
- `TODO.md`: open follow-up items (gitignored globally).

This package must not contain `.claude-plugin/`, `.codex-plugin/`, `.agents/plugins/marketplace.json`, or root `plugin.json`. Adding any of those flips the APM lockfile classification from `apm_package` to `marketplace_plugin` and suppresses skill deployment to every runtime.

## Skill source parity

`.apm/skills/<name>/SKILL.md` and `.opencode/skills/<name>/SKILL.md` must stay byte-identical. Verify with:

```bash
for f in .apm/skills/*/SKILL.md; do
  diff "$f" ".opencode/skills/$(basename "$(dirname "$f")")/SKILL.md" || echo "DIFF: $f"
done
```

When adding or modifying a skill, update both `SKILL.md` copies. Files under `.apm/skills/<name>/agents/`, `references/`, `scripts/`, or `examples/` are canonical at `.apm/skills/` and are not mirrored.

## Source validation

```bash
python3 -m json.tool opencode.jsonc >/dev/null
python3 -m json.tool .opencode/package.json >/dev/null
python3 -c "import yaml, pathlib; yaml.safe_load(pathlib.Path('apm.yml').read_text())"
python3 -c "import yaml, pathlib; [yaml.safe_load(p.read_text()) for p in pathlib.Path('.apm/skills').glob('*/agents/openai.yaml')]"
```

## Runtime checks

Local CLIs needed: `apm`, plus any runtime CLI you want to verify (`claude`, `codex`, `copilot`, `gemini`, `opencode`).

- `apm install`, `apm update`, `apm uninstall` in a clean temp project with the runtime root directories pre-created: `.agents/`, `.claude/`, `.cursor/`, `.opencode/`, `.gemini/`, `.github/`, `.windsurf/`. The legacy `apm install --update` form still works but prints a deprecation notice.
- `apm install brackendev/jsp-skills -g [--target ...]` and `apm uninstall brackendev/jsp-skills -g` to exercise user-scope install. Local-path form (`apm install /absolute/path -g`) is also accepted.
- OpenCode: `opencode --pure debug skill` lists the deployed skills and their source paths.
