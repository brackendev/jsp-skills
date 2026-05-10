# TODO

## In Progress

## Blocked

## Next Up

### Tier boundary guard

- [ ] Add PreToolUse hook to warn on wrong-tier file edits in Tier 3
  - Approach: Check Edit/Write/MultiEdit targets against ownership map (Tier 2-owned, merge zone). Return `permissionDecision: "ask"` with explanation. Uses `JSP_TIER` env var from tier-detect.sh.
  - Files: jsp-skills/hooks/tier-boundary-guard.sh, jsp-skills/hooks/hooks.json
  - Trigger: Add if developers report accidentally editing Tier 2 files in Tier 3 projects
