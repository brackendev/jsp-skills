---
name: deploy-check
description: Pre-deployment verification checklist before production release
allowed-tools: Read, Bash
user-invocable: true
disable-model-invocation: true
---

# Pre-Deployment Verification

Run release readiness checks before production deployment with Kamal.

## Step 1: Full Environment Verification

```bash
make verify
```

Destroys local environment, rebuilds from scratch, runs all tests, verifies server starts.

Time: ~15-20 minutes. If fails, DO NOT deploy.

## Step 2: Review Migrations

```bash
make exec ARGS="bin/rails db:migrate:status"
ls -la db/migrate/
```

Safety review:
- [ ] Zero-downtime patterns
- [ ] Indexes created before foreign keys
- [ ] Data migrations use batches (<1000 rows per batch)
- [ ] Tested rollback: `make rails ARGS="db:rollback"`

## Step 3: Verify Production Credentials

```bash
make shell
EDITOR="vim" bin/rails credentials:show --environment production
```

Required: `secret_key_base`, payment processor keys, email API keys, OAuth credentials

## Step 4: Check Dependencies

```bash
make exec ARGS="bundle outdated"
make exec ARGS="bundle audit"
```

## Step 5: Prepare Rollback Plan

```bash
# Kamal rollback
kamal rollback

# Database rollback (if needed)
kamal app exec -i "bin/rails db:rollback"
```

## Step 6: Validate Kamal Config

```bash
kamal config
```

---

## Red Flags (Stop Deployment)

DO NOT deploy if:
- `make verify` fails
- Any tests failing
- Migrations are unsafe
- No rollback plan
- Production credentials missing
- Security vulnerabilities in dependencies

---

## When to Escalate

After checklist passes, the `deployment-specialist` skill activates automatically and covers:
- Kamal deployment execution
- Health checks and monitoring
- Rollback if needed

---

## Reference Documentation

- Kamal docs: https://kamal-deploy.org/docs/
- Testing guide: see `docs/shared/TESTING.md` in the JSP upstream
