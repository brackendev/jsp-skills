---
name: troubleshooting
description: Development environment diagnostics guide that MUST activate when user mentions "Docker error", "container won't start", "SSL certificate", "make setup failed", "port already in use", "permission denied", "can't connect to database", or describes Docker/SSL/Make/container-specific issues. Provides first-line triage for infrastructure problems. Activates proactively for development environment issues.
allowed-tools: Read, Grep, Bash, AskUserQuestion
user-invocable: false
---

# Troubleshooting Guide

Quick diagnostics for Docker, SSL, Make, and database issues in the development environment.

## When This Activates

- Docker errors ("container won't start", "Docker daemon")
- SSL certificate issues ("certificate warning", "SSL error")
- Container/service failures ("postgres won't start", "redis connection refused")
- Make command failures ("make setup failed", "make up failed")
- Port conflicts ("port already in use", "address already in use")
- Permission errors in Docker context

## Step 1: Triage the Issue

**If the user's problem isn't immediately clear, ask to narrow down:**

Use AskUserQuestion with:
- header: "Issue type"
- question: "What type of problem are you experiencing?"
- options:
  - label: "Docker/containers"
    description: "Container won't start, Docker daemon errors, make up fails"
  - label: "SSL/certificates"
    description: "Browser warnings, certificate not found errors"
  - label: "Database"
    description: "Connection refused, migration failures, seed errors"
  - label: "Tests failing"
    description: "System tests timing out, parallel test issues"

**After user responds, jump directly to the relevant section below.**

If the user already specified their issue clearly (e.g., "Docker won't start"), skip the question and go directly to that section.

---

## Quick Diagnosis Table

| Symptom | Quick Fix | Section |
|---------|-----------|---------|
| Docker container won't start | `make clean && make build ARGS="--no-cache" && make setup` | [Docker](#docker-issues) |
| Browser SSL warning | Accept certificate (normal for dev) | [SSL](#ssl-issues) |
| Can't connect to database | `make logs ARGS="postgres"` → wait for "ready to accept connections" | [Database](#database-issues) |
| Tests failing | `make clean && make setup && make test-all` | [Tests](#test-issues) |
| Port already in use | `lsof -i :3001` → `kill -9 <PID>` | [Ports](#port-issues) |
| Permission denied | `chmod -R 777 log tmp` | [Permissions](#permission-issues) |

## The 80% Fix

**When in doubt, try this first:**

```bash
make clean
make build ARGS="--no-cache"
make setup
```

This destroys the environment and rebuilds from scratch. Fixes most issues.

---

## Docker Issues

### Docker Not Running

**Symptom:**
```
Cannot connect to the Docker daemon
```

**Fix:**
```bash
# macOS: Start Docker Desktop
open -a Docker

# Verify it's running
docker ps
```

### Containers Won't Start

**Symptom:** Container exits immediately or restarts in a loop

**Diagnosis:**
```bash
# Check what's running
make ps

# View logs for errors
make logs ARGS="-f"
```

**Common causes:**
- Port conflict (something using 3001 or 54377)
- Missing .env file
- Corrupted volume

**Fix:**
```bash
# Check for port conflicts
lsof -i :3001  # Web server
lsof -i :54377 # PostgreSQL

# Kill conflicting process if found
kill -9 <PID>

# Ensure .env exists
cp .env.example .env

# Clean rebuild
make clean
make build ARGS="--no-cache"
make setup
```

---

## SSL Issues

### Self-Signed Certificate Warning

**Symptom:** Browser shows "Your connection is not private"

**Fix:** **This is expected and safe for local development.**

Click "Advanced" → "Proceed to localhost (unsafe)"

You'll need to do this once per browser.

### Certificate Not Found

**Symptom:**
```
SSL_CTX_use_certificate_file: No such file or directory
```

**Fix:**
```bash
# Generate certificates
make setup-ssl

# Verify they exist
ls -la .dev/ssl/
# Should show localhost.pem and localhost-key.pem

# Restart services
make restart
```

---

## Database Issues

### Connection Refused

**Symptom:**
```
PG::ConnectionBad: could not connect to server
```

**Fix:**
```bash
# Check if postgres is running
make ps

# If not running
make up

# Wait for postgres to be ready
make logs ARGS="-f postgres"
# Look for: "database system is ready to accept connections"

# Then try again
make migrate
```

### Migration Failures

**Symptom:**
```
StandardError: An error has occurred, all later migrations canceled
```

**Fix:**
```bash
# Check migration status
make exec ARGS="bin/rails db:migrate:status"

# If corrupted, reset (WARNING: destroys data)
make clean
make setup
```

### Seed Data Errors

**Symptom:**
```
ActiveRecord::RecordInvalid: Validation failed
```

**Fix:**
```bash
# Reset database and re-seed
make rails ARGS="db:reset"

# Or test seeds specifically
make test-seeds
```

---

## Test Issues

### System Tests Timing Out

**Symptom:**
```
Selenium::WebDriver::Error::TimeoutError
```

**Fix:**
```bash
# Ensure services are running
make up

# Wait for server to be fully ready
make logs ARGS="-f web"
# Look for: "Listening on https://0.0.0.0:3001"

# Then retry tests
make test-system
```

### Parallel Test Database Issues

**Symptom:**
```
PG::ObjectInUse: database "jumpstart_test" is being accessed
```

**Fix:**
```bash
# Stop everything
make down

# Clean rebuild
make clean
make setup

# Retry tests
make test-all
```

---

## Port Issues

### Port Already in Use

**Symptom:**
```
Error: bind: address already in use
```

**Find what's using the port:**
```bash
lsof -i :3001
```

**Kill it:**
```bash
kill -9 <PID>
```

**Or use different ports** (edit .env):
```bash
# Change in .env
PORT=3002
POSTGRES_PORT=54378

make restart
```

---

## Permission Issues

### Permission Denied Errors

**Symptom:**
```
Permission denied: '/app/log/development.log'
Permission denied @ dir_s_mkdir - /app/tmp
```

**Fix:**
```bash
chmod -R 777 log tmp app/assets/builds db
make restart
```

---

## Make Command Issues

### make up Fails Immediately

**Diagnosis:**
```bash
# Check for .env file
ls -la .env

# If missing
cp .env.example .env

# Check compose.yaml syntax
docker compose config

# View actual error
make logs
```

### make shell Can't Find Container

**Symptom:**
```
Error: No such container
```

**Fix:**
```bash
# Check running containers
make ps

# If not running
make up

# Check actual container names
docker ps --format "table {{.Names}}"
```

---

## Tailwind CSS Issues

### CSS Not Compiling

**Symptom:** Style changes not reflected in browser

**Fix:**
```bash
# Check if css watcher is running
make logs ARGS="css"

# Procfile.dev should use polling mode
cat Procfile.dev | grep tailwindcss
# Should show: bin/rails tailwindcss:watch[poll]

# Restart to pick up changes
make restart
```

---

## General Debugging Process

When encountering any issue, follow this process:

**1. Check logs first:**
```bash
make logs ARGS="-f"     # All services
make logs ARGS="web"    # Specific service
```

**2. Verify services are running:**
```bash
make ps
```

**3. Check environment:**
```bash
cat .env
make exec ARGS="env | grep -E '(RAILS|DATABASE|REDIS|SSL)'"
```

**4. Try the 80% fix:**
```bash
make clean
make build ARGS="--no-cache"
make setup
```

**5. Full verification (if still broken):**
```bash
make verify
```

This runs a complete integrity check from a clean state.

---

## Reference Documentation

For detailed troubleshooting, see `docs/shared/TROUBLESHOOTING.md` in the JSP upstream.

Covers:
- Docker issues (volume permissions, networking)
- SSL certificate problems
- Database connection errors
- Test failures (WebMock, parallel tests)
- Asset pipeline errors
- Development server issues

See also `docs/shared/TESTING.md` and `docs/shared/MAKEFILE.md` in the JSP upstream.

---

## When to Escalate

If issues persist, the appropriate specialist skill will activate based on context:

- **Database:** `database-specialist`
- **Multi-tenancy:** `multi-tenancy-specialist`
- **Billing/Pay gem:** `billing-specialist`
- **Frontend/Hotwire:** `hotwire-specialist`
- **Security:** `security-auditor`
- **Deployment:** `deployment-specialist`

---

## Still Stuck?

**Check recent changes:**
```bash
git log --oneline -10
git diff HEAD~1
```

**Compare with known working state:**
```bash
git stash
make clean && make setup && make test-all
git stash pop
```

**Search for similar issues:**
- Jumpstart Pro docs: https://jumpstartrails.com/docs
