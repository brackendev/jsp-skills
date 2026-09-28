---
name: deploy-check
description: "Pre-deployment readiness checklist for production. Runs environment verification (make verify rebuilds the local environment and runs the full test suite), migration safety review, and credential and dependency checks, then produces a go/no-go with evidence."
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
make rails db:migrate:status
ls -la db/migrate/
```

Safety review:
- [ ] Zero-downtime patterns
- [ ] Indexes created before foreign keys
- [ ] Data migrations use batches (<1000 rows per batch)
- [ ] Tested rollback: `make rails db:rollback`

## Step 3: Verify Production Credentials

Do not run `bin/rails credentials:show` on its own. It prints every production secret into the terminal and the session transcript. Pipe it through a filter that prints only the key names and whether each value is set:

```bash
make shell
bin/rails credentials:show --environment production | ruby -ryaml -e '
  data = YAML.safe_load($stdin.read, aliases: true)
  abort "Could not read the production credentials." unless data.is_a?(Hash)
  print_keys = lambda do |node, path|
    return puts("#{path.join(".")}: #{node.to_s.empty? ? "EMPTY" : "set"}") unless node.is_a?(Hash)
    node.each { |key, value| print_keys.call(value, path + [key]) }
  end
  print_keys.call(data, [])'
```

Required: `secret_key_base`, payment processor keys, email API keys, OAuth credentials (`omniauth.<provider>.public_key` and `private_key`). Any required key reported as `EMPTY` or absent is a stop condition. The filter aborts when the output is not credentials YAML, which usually means `config/credentials/production.key` is missing.

## Step 4: Check Dependencies

```bash
make exec bundle outdated
make exec bundle audit
```

## Step 5: Prepare Rollback Plan

```bash
# Kamal rollback (requires the version to restore; list versions with `kamal app containers`)
kamal rollback VERSION

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
