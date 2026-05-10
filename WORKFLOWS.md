# jsp-skills Workflows

Real-world skill sequences for Jumpstart Pro Rails development.

**Skills** activate automatically on triggers (e.g., `rails g model` triggers `account-scoping`).

**Agents** activate based on your prompt (e.g., "Add Stripe billing" → `billing-specialist`).

## Session Flows

### New Work → Pause

```bash
/overview             # analyze codebase structure and tooling
# ... work ...
# /check              # run and fix format, lint, test, build
# /sync-tests         # align tests with changed files
# /sync-docs          # align project documentation
# /issue              # create issue with summary
/pause                # capture state, update TODO.md, generate prompt
/clear                               # copy prompt first
```

### New Work → Commit

```bash
/overview             # analyze codebase structure and tooling
# ... work ...
# /check              # run and fix format, lint, test, build
# /sync-tests         # align tests with changed files
# /sync-docs          # align project documentation
# /issue              # create issue with summary
/commit               # run tests, docs, check, commit, generate prompt
/clear                               # copy prompt first
```

### New Work → PR

```bash
/overview             # analyze codebase structure and tooling
# ... work ...
# /check              # run and fix format, lint, test, build
# /sync-tests         # align tests with changed files
# /sync-docs          # align project documentation
# /issue              # create issue with summary
/commit               # run tests, docs, check, commit, generate prompt
/jsp-skills:ship 42 Add feature             # branch, commit, push, create PR, label
# /clear                             # copy prompt first (optional)
```

### Continue Work → Pause

```bash
# /overview           # analyze codebase (if unfamiliar)
[paste prompt]
# ... work ...
# /check              # run and fix format, lint, test, build
# /sync-tests         # align tests with changed files
# /sync-docs          # align project documentation
# /issue              # create issue with summary
/pause                # capture state, update TODO.md, generate prompt
/clear                               # copy prompt first
```

### Continue Work → Commit

```bash
# /overview           # analyze codebase (if unfamiliar)
[paste prompt]
# ... work ...
# /check              # run and fix format, lint, test, build
# /sync-tests         # align tests with changed files
# /sync-docs          # align project documentation
# /issue              # create issue with summary
/commit               # run tests, docs, check, commit, generate prompt
/clear                               # copy prompt first
```

### Continue Work → PR

```bash
# /overview           # analyze codebase (if unfamiliar)
[paste prompt]
# ... work ...
# /check              # run and fix format, lint, test, build
# /sync-tests         # align tests with changed files
# /sync-docs          # align project documentation
# /issue              # create issue with summary
/commit               # run tests, docs, check, commit, generate prompt
/jsp-skills:ship 42 Add feature             # branch, commit, push, create PR, label
# /clear                             # copy prompt first (optional)
```

---

## Tier 2 Sync

Pull infrastructure updates:

```bash
/jsp-skills:sync                            # pull Tier 2 updates, merge, create PR
# ... tier2-sync skill guides conflicts ...
/check                # run and fix format, lint, test, build
```

---

## Troubleshooting

`troubleshooting` skill activates on error keywords.

### Docker Issues

```bash
make down
make clean                           # or: make clobber (nuclear)
make setup
make up
/check                # run and fix format, lint, test, build
```

### SSL Issues

```bash
make setup-ssl
make up
# Test: https://localhost:3001
```

