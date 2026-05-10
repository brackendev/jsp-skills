---
name: sync
description: Pull Tier 2 updates into jsp-fork-master, merge to working branch, and create PR
allowed-tools: Bash(git checkout:*), Bash(git pull:*), Bash(git branch:*), Bash(git merge:*), Bash(git push:*), Bash(git add:*), Bash(git commit:*), Bash(git show:*), Bash(git diff:*), Bash(git status:*), Bash(git restore:*), Bash(date:*)
user-invocable: true
disable-model-invocation: true
---

Pull latest changes from Tier 2 and create a PR for merging into master.

**Arguments:** None

**Steps:**

1. **Verify this is Tier 3**:
   - Run `git branch --list jumpstartpro-main`
   - If `jumpstartpro-main` exists: ERROR - This is Tier 2, not Tier 3
   - The `jumpstartpro-main` branch only exists in Tier 2
   - Tier 3 has `jsp-fork-master` instead
   - Stop execution and inform the user this skill is only for Tier 3

2. **Check for uncommitted changes**:
   - Run `git status --porcelain`
   - If output is not empty: ERROR - Uncommitted changes detected
   - Inform user to commit or stash changes before syncing

3. **Switch to jsp-fork-master**:
   - Run `git checkout jsp-fork-master`

4. **Pull latest Tier 2 changes**:
   - Run `git pull jsp-fork master`
   - This fetches and merges the latest changes from Tier 2

5. **Switch to master**:
   - Run `git checkout master`

6. **Create timestamped working branch**:
   - Run `date +%Y%m%d` to get current date
   - Run `git checkout -b task/pull-tier2-updates-YYYYMMDD`
   - Example: `git checkout -b task/pull-tier2-updates-20260119`

7. **Merge jsp-fork-master**:
   - Run `git merge jsp-fork-master --no-commit` (allows conflict resolution before commit)
   - Check exit code to detect conflicts

8. **Protect Tier 3 directories**:

   Restore Tier 3 directories wholesale. This handles deletions, renames, and edits from Tier 2 that would otherwise clobber Tier 3 code:

   ```bash
   git restore --source=HEAD --staged --worktree -- app/ test/
   ```

   Then restore Tier 2's seed tests (infrastructure, not app code):
   ```bash
   git checkout jsp-fork-master -- test/seeds/ 2>/dev/null && git add test/seeds/ 2>/dev/null
   ```

   Re-apply Tier 2 app-level additions that Tier 3 does not have yet (e.g., new engine overrides). Without this, the wholesale restore above removes new Tier 2 files from `app/`:
   ```bash
   git diff --name-only --diff-filter=A HEAD...jsp-fork-master -- app/ | xargs -I{} git checkout jsp-fork-master -- {} 2>/dev/null
   git diff --name-only --diff-filter=A HEAD...jsp-fork-master -- app/ | xargs -I{} git add {} 2>/dev/null
   ```

9. **Handle remaining conflicts**:

   Run `git diff --name-only --diff-filter=U` to list conflicted files, then resolve by category:

   **Keep Tier 3 version (`--ours`):**
   - `README.md` — Project documentation
   - `config/jumpstart.yml` — Project configuration

   ```bash
   git checkout --ours README.md && git add README.md
   git checkout --ours config/jumpstart.yml 2>/dev/null && git add config/jumpstart.yml 2>/dev/null
   ```

   **Accept Tier 2 version (`--theirs`):**
   - `CLAUDE.md` — Upstream-owned (Tier 2 guidance lives in `.claude/rules/`)
   - `.claude/rules/` — Tier 2 rules files (numbered 10-50)
   - `Makefile` — Infrastructure
   - `compose.yaml` — Docker configuration
   - `Dockerfile.dev` — Development container
   - `.github/workflows/ci.yml` — CI pipeline
   - `docs/**` — Shared documentation
   - `templates/**` — Project templates
   - `test/seeds/**` — Seed integrity tests

   ```bash
   git checkout --theirs CLAUDE.md && git add CLAUDE.md
   git checkout --theirs .claude/rules/ 2>/dev/null && git add .claude/rules/ 2>/dev/null
   git checkout --theirs Makefile compose.yaml Dockerfile.dev && git add Makefile compose.yaml Dockerfile.dev
   git checkout --theirs .github/workflows/ci.yml 2>/dev/null && git add .github/workflows/ci.yml 2>/dev/null
   git checkout --theirs docs/ && git add docs/
   git checkout --theirs templates/ 2>/dev/null && git add templates/ 2>/dev/null
   ```

   **Manual review required:**
   - `config/database.yml` — Keep customizations, accept structure changes
   - `package.json` — Merge both if modified

   **Gemfile merge** (requires combining both versions):

   Extract gems from both tiers:
   ```bash
   # Show Tier 3 Gemfile (current)
   git show HEAD:Gemfile > /tmp/gemfile-tier3.rb
   # Show Tier 2 Gemfile (incoming)
   git show jsp-fork-master:Gemfile > /tmp/gemfile-tier2.rb
   ```

   Resolution approach:
   1. Start with Tier 2 as base: `git checkout --theirs Gemfile`
   2. Review `/tmp/gemfile-tier3.rb` for Tier 3-specific gems (app dependencies)
   3. Add any missing Tier 3 gems back to Gemfile
   4. Run `git add Gemfile`

   Common Tier 3 gems to preserve (check `/tmp/gemfile-tier3.rb`):
   - App-specific gems not in Tier 2
   - Custom gem versions pinned for compatibility
   - Development/test gems added locally

   After Gemfile is merged:
   ```bash
   git checkout --theirs Gemfile.lock
   git add Gemfile.lock
   # After merge completes, regenerate lock: make exec bundle lock
   ```

   **Preserve README-FORK.md** (Tier 2 reference):
   - Run `git show jsp-fork-master:README.md > README-FORK.md`
   - Run `git add README-FORK.md`

   After resolving all conflicts, check for remaining:
   - Run `git diff --name-only --diff-filter=U`
   - If files remain, inform user which files need manual resolution and stop

10. **Complete merge**:
    - Run `git commit` (uses auto-generated merge message)
    - If no conflicts occurred in step 7, run `git commit` to finalize the merge

11. **Push working branch**:
    - Run `git push -u origin HEAD`

12. **Create PR using /jsp-skills:ship**:
    - Execute `/jsp-skills:ship` to create PR with auto-generated description and labels
    - PR will reference the Tier 2 updates merged

**Example usage:**
```bash
/jsp-skills:sync
```

**What this skill does:**
- Automates the Tier 3 update workflow
- Protects Tier 3 directories (app/, test/) via wholesale restore after merge
- Auto-resolves known conflicts using documented strategies
- Creates a working branch for review instead of direct master push
- Uses /jsp-skills:ship for consistent PR creation with proper labels
- Follows the three-tier structure: Jumpstart Pro → Tier 2 → Tier 3

**Directory protection and conflict resolution:**
| File Type | Strategy | Reason |
|-----------|----------|--------|
| App code (app/) | Wholesale restore + re-apply Tier 2 additions | Tier 3 app code protected; new Tier 2 overrides (e.g., engine fixes) re-applied |
| Tests (test/, except seeds) | Wholesale restore | Tier 3 application tests, protected from all Tier 2 changes |
| Seed tests (test/seeds/) | Accept Tier 2 | Infrastructure tests from Tier 2 |
| CLAUDE.md | Accept Tier 2 | Upstream-owned; Tier 2 guidance lives in `.claude/rules/` |
| `.claude/rules/` (10-50) | Accept Tier 2 | Tier 2 infrastructure rules |
| `.claude/rules/` (90+) | Keep Tier 3 | App-specific rules added by Tier 3 |
| README.md | Keep Tier 3 | Project documentation |
| Infrastructure (Makefile, compose.yaml, Dockerfile.dev) | Accept Tier 2 | Shared infrastructure |
| Workflows (.github/workflows/) | Accept Tier 2 | CI/CD improvements |
| Documentation (docs/) | Accept Tier 2 | Shared guides |
| Dependencies (Gemfile) | Tier 2 base + Tier 3 gems | Infrastructure from Tier 2, app gems from Tier 3 |

**When to use:**
- Periodically to stay current with Tier 2 infrastructure improvements
- Before major releases to ensure latest Tier 2 changes are included
- After Tier 2 maintainers announce updates

**Reference:** See `docs/tier3/UPDATING.md` for manual workflow and troubleshooting.
