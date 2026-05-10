#!/bin/bash
# Tier Detection - SessionStart hook
# Detects whether the current project is Tier 2 or Tier 3 and injects
# context into the session. Also persists JSP_TIER via CLAUDE_ENV_FILE
# so subsequent hooks can read it without re-running git commands.
#
# Detection logic:
#   - jumpstartpro-main branch exists => Tier 2
#   - jsp-fork-master branch exists   => Tier 3
#   - Neither                         => Not a JSP project (silent exit)

set -euo pipefail

# Only run on startup (not resume/clear/compact)
INPUT=$(cat)
SOURCE=$(echo "$INPUT" | jq -r '.source // "startup"')
if [[ "$SOURCE" != "startup" ]]; then
  exit 0
fi

TIER=""

if git branch --list jumpstartpro-main 2>/dev/null | grep -q jumpstartpro-main; then
  TIER="2"
elif git branch --list jsp-fork-master 2>/dev/null | grep -q jsp-fork-master; then
  TIER="3"
fi

# Not a JSP project
if [[ -z "$TIER" ]]; then
  exit 0
fi

# Persist tier for other hooks
if [[ -n "${CLAUDE_ENV_FILE:-}" ]]; then
  echo "export JSP_TIER=$TIER" >> "$CLAUDE_ENV_FILE"
fi

# Inject context into session
if [[ "$TIER" == "3" ]]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: "JSP TIER CONTEXT: This is a Tier 3 (application) project. Infrastructure files are owned by Tier 2 and will be overwritten on the next /jsp-skills:sync. Tier 2-owned files: Makefile, compose.yaml, Dockerfile.dev, CLAUDE.md (root), .claude/rules/ (numbered 10-50), .github/workflows/, docs/, templates/, test/seeds/. Manual-merge files (shared ownership): Gemfile, package.json, config/database.yml. When editing Tier 2-owned files, warn the user that changes will not survive the next sync. Suggest making the change in the Tier 2 repo instead."
    }
  }'
elif [[ "$TIER" == "2" ]]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: "JSP TIER CONTEXT: This is a Tier 2 (shared infrastructure) project. App-specific code belongs in Tier 3. Tier 3-owned paths: app/ (application code), test/ (except test/seeds/), README.md, config/jumpstart.yml, .claude/rules/ (numbered 90+). When editing Tier 3-owned paths, warn the user that these changes belong in the application repo, not the shared fork."
    }
  }'
fi

exit 0
