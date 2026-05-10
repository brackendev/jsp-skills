---
name: tier2-sync
description: Tier 2 sync workflow that activates on "fork updates", "sync fork", "pull from fork", "tier 2 updates", or /jsp-skills:sync. Directs to /jsp-skills:sync for automated workflow.
allowed-tools: Bash(git branch:*)
user-invocable: false
---

# Tier 2 Sync Guide

## Tier Detection (Check First)

**This skill is ONLY for Tier 3.**

```bash
git branch --list jumpstartpro-main
```

- **If branch exists:** You are in Tier 2. This skill does not apply. See `docs/tier2/UPSTREAM_MERGE.md`.
- **If branch does not exist:** You are in Tier 3. Continue below.

## Workflow

Run the sync skill:

```bash
/jsp-skills:sync
```

It handles:
- Fetching Tier 2 updates into jsp-fork-master
- Creating timestamped merge branch
- Auto-resolving conflicts (keeps app code, accepts infrastructure)
- Guiding through Gemfile merge
- Creating PR via /jsp-skills:ship

## Troubleshooting

If the merge fails or tests break after sync, see `docs/tier3/UPDATING.md` for manual resolution steps.
