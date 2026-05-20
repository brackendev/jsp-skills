---
name: upstream-sync
description: Mutating skill. Merge Jumpstart Pro Rails (JSP) upstream changes into the project on a working branch and push it for review, preserving project customizations through a merge-base divergence audit. Pass `--report` to produce the divergence audit only, without merging, committing, or pushing.
allowed-tools: Bash(git checkout:*), Bash(git fetch:*), Bash(git pull:*), Bash(git branch:*), Bash(git merge:*), Bash(git merge-base:*), Bash(git push:*), Bash(git add:*), Bash(git commit:*), Bash(git show:*), Bash(git diff:*), Bash(git status:*), Bash(git restore:*), Bash(git remote:*), Bash(git symbolic-ref:*), Bash(date:*), Bash(comm:*), Bash(sort:*), Bash(diff:*), Bash(grep:*), Bash(sed:*), Bash(wc:*), Bash(cat:*), Bash(rm:*), Read, AskUserQuestion
user-invocable: true
disable-model-invocation: true
---

Merge the latest Jumpstart Pro Rails (JSP) upstream changes into a project that started as a clone of the Jumpstart Pro template. The skill's first priority is to never silently overwrite project customizations. Every path that diverges between the project and upstream is classified, every both-changed path is surfaced for review, and project-only changes are verified intact before the merge commit is created.

JSP is shorthand for Jumpstart Pro Rails (https://jumpstartrails.com/), a paid SaaS Rails template distributed as a Git repository that customers clone, customize, and upgrade by merging from the upstream repository.

**Prerequisites:**

- The project has the Jumpstart Pro Rails repository configured as a Git remote named `jumpstart-pro`. Verify with `git remote -v`. If the remote is missing, add it with `git remote add jumpstart-pro <jsp-repo-url>` before running this skill.

## Arguments

| Input             | Effect                                                                                          |
|-------------------|-------------------------------------------------------------------------------------------------|
| (no argument)     | Merge `jumpstart-pro/main` into the project, run the divergence audit, push the working branch. |
| `all`             | Same as no argument. Accepted for family consistency.                                           |
| `<path>` `<glob>` | Same as no argument. The merge spans the whole repository; per-path scope is not meaningful. Accepted for family consistency. |
| `--report`        | Run the divergence audit only. Write `/tmp/jsp-sync-report.md` and stop before the merge. No worktree changes, no commit, no push. |

Only the literal token `--report` triggers report mode. Natural-language phrases such as `preview` or `dry run` are treated as scope input and ignored.

## Mutation

The skill mutates by default: it merges `jumpstart-pro/main`, applies the project-owned path policy, resolves remaining conflicts (pausing for operator input where the policy requires manual review), commits the merge, and pushes the working branch to `origin`.

Under `--report`, the skill runs steps 1-10 only (clean up, verify remote, detect primary branch, refuse a dirty worktree, fetch, review upgrade notes, update primary branch, compute divergence, create the timestamped working branch, run the pre-merge audit), then writes `/tmp/jsp-sync-report.md` with the path counts and the both-changed-needs-review list and stops. Steps 11-19 (the merge, project-owned restore, conflict resolution, Gemfile opt-in, no-clobber verification, drift detection, commit, push) are skipped. The audit file is the report.

Intermediate scratch files matching `/tmp/jsp-sync-*` are written in both modes; they are the audit evidence rather than project mutations.

**Steps:**

1. **Clean up stale temporary files**:
   - Remove any leftover sync artifacts from a previous run: `rm -f /tmp/jsp-sync-*`.

2. **Verify the `jumpstart-pro` remote**:
   - Run `git remote -v`.
   - If no `jumpstart-pro` remote is listed: ERROR. Ask the user to add the JSP repository as a Git remote named `jumpstart-pro`, then stop.

3. **Detect the project's primary branch**:
   - Run `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'`. The output is typically `main` or `master`.
   - If the command returns empty, use `AskUserQuestion` to ask the user for the primary branch name.
   - Save the result as `<primary>` for the remaining steps.

4. **Check for uncommitted changes**:
   - Run `git status --porcelain`.
   - If output is not empty: ERROR. Ask the user to commit or stash changes before syncing, then stop.

5. **Fetch the upstream**:
   - Run `git fetch jumpstart-pro`.

6. **Review upstream upgrade notes**:
   - Check whether upstream maintains an `UPGRADE.md`: `git show jumpstart-pro/main:UPGRADE.md 2>/dev/null`.
   - If the file exists, display its contents to the user. Upgrade notes typically describe schema migrations, gem version increments, and configuration changes that should be addressed before merging.
   - Use `AskUserQuestion` to ask whether to continue with the sync or stop and address the upgrade notes first.
   - If the file does not exist on `jumpstart-pro/main`, skip this step.

7. **Update the local primary branch**:
   - Run `git checkout <primary>`.
   - Run `git pull --ff-only`.

8. **Compute the merge base and classify divergence**:

   ```bash
   MERGE_BASE=$(git merge-base HEAD jumpstart-pro/main)
   git diff --name-only "$MERGE_BASE"...HEAD | sort > /tmp/jsp-sync-project-changes.txt
   git diff --name-only "$MERGE_BASE"...jumpstart-pro/main | sort > /tmp/jsp-sync-upstream-changes.txt
   comm -12 /tmp/jsp-sync-project-changes.txt /tmp/jsp-sync-upstream-changes.txt > /tmp/jsp-sync-both-changed.txt
   comm -23 /tmp/jsp-sync-project-changes.txt /tmp/jsp-sync-upstream-changes.txt > /tmp/jsp-sync-project-only.txt
   comm -13 /tmp/jsp-sync-project-changes.txt /tmp/jsp-sync-upstream-changes.txt > /tmp/jsp-sync-upstream-only.txt
   ```

   Filter the both-changed list to the paths that will actually need review (excluding paths the project-owned policy will overwrite back to the project version):

   ```bash
   grep -Ev '^(app/|test/|README\.md$|CLAUDE\.md$|AGENTS\.md$|\.claude/|\.cursor/|Makefile$|compose\.yaml$|Dockerfile\.dev$|\.github/|docs/|templates/|UPGRADE\.md$|Gemfile$|Gemfile\.lock$|config/jumpstart\.yml$)' /tmp/jsp-sync-both-changed.txt > /tmp/jsp-sync-both-changed-needs-review.txt || true
   ```

9. **Create a timestamped working branch**:
   - Skip this step when invoked with `--report`.
   - Run `date +%Y%m%d`.
   - Run `git checkout -b task/pull-upstream-YYYYMMDD`.

10. **Pre-merge audit**:
    - Show the user the counts: project-only, upstream-only, and both-changed (with the "needs review" subset called out).
    - Display the contents of `/tmp/jsp-sync-both-changed-needs-review.txt` so the user knows which paths Git will attempt to auto-merge.
    - When invoked with `--report`: write a pre-merge audit to `/tmp/jsp-sync-report.md` containing the path counts, the upstream-only list (first 30 paths with "and N more" if longer), the project-only list (same), the both-changed-needs-review list in full, and a note that this is a pre-merge audit only (no merge was performed). Report the file path to the user and stop. Do not run steps 11-19.
    - Otherwise, use `AskUserQuestion` to ask whether to proceed with the merge. Options: continue, or stop here so the user can inspect manually.

11. **Merge `jumpstart-pro/main`**:
    - Run `git merge jumpstart-pro/main --no-commit --no-ff`.
    - Do not commit; the next steps apply project-owned policy and verify the no-clobber invariant before the commit is created.

12. **Apply project-owned policy**:

    Wholesale-restore project-owned paths to the project version. The same `git restore --source=HEAD` command removes `.cursor/` and `UPGRADE.md` because the project does not carry copies; for paths present in `HEAD`, files are restored to the project version, and for paths absent in `HEAD`, the staged and worktree copies brought in by the merge are removed.

    ```bash
    git restore --source=HEAD --staged --worktree -- \
      app/ test/ README.md CLAUDE.md AGENTS.md .claude/ .cursor/ Makefile \
      compose.yaml Dockerfile.dev .github/ docs/ templates/ UPGRADE.md \
      Gemfile Gemfile.lock
    ```

    `test/seeds/` is restored as part of `test/`. `config/jumpstart.yml` is resolved in step 13.

13. **Resolve remaining conflicts**:

    Run `git diff --name-only --diff-filter=U` to list any files still in conflict (the wholesale-restore in step 12 resolved most project-owned paths). Handle remaining conflicts by category:

    **Keep project version (`--ours`):**
    - `config/jumpstart.yml`
    ```bash
    git checkout --ours config/jumpstart.yml 2>/dev/null && git add config/jumpstart.yml 2>/dev/null
    ```

    **Manual review (pause for user):**
    - `config/database.yml`, `package.json`: surface these files to the user with their conflict markers and ask for resolution before continuing.

    **Any other remaining conflicts:**
    - For each remaining conflicted path, present the project version, upstream version, and conflict markers to the user. Ask the user how to resolve: keep project, take upstream, or hand-edit. Stage each resolved file before continuing.

    After resolution, run `git diff --name-only --diff-filter=U` and confirm the output is empty. If files remain, stop and inform the user.

14. **Process Gemfile opt-in**:

    The project's `Gemfile` was restored to the project version in step 12. Surface upstream gem changes so the user can opt in to anything they want:

    ```bash
    diff <(git show HEAD:Gemfile) <(git show jumpstart-pro/main:Gemfile) > /tmp/jsp-sync-gemfile-diff.txt
    ```

    Display the diff and use `AskUserQuestion` to ask whether to incorporate any upstream gem changes. If yes, edit the project's `Gemfile` per the user's choice and stage it. Inform the user that `Gemfile.lock` should be regenerated after the merge commit with `make exec bundle lock` (or `bundle lock`).

15. **Verify the no-clobber invariant**:

    Confirm that no path the project changed (but upstream did not) was modified by the merge process. After step 12, every path in `/tmp/jsp-sync-project-only.txt` should be byte-identical to the project's `HEAD`.

    ```bash
    : > /tmp/jsp-sync-clobbered.txt
    while read -r path; do
      [ -z "$path" ] && continue
      if ! git diff --quiet HEAD -- "$path" 2>/dev/null \
         || ! git diff --cached --quiet HEAD -- "$path" 2>/dev/null; then
        echo "$path" >> /tmp/jsp-sync-clobbered.txt
      fi
    done < /tmp/jsp-sync-project-only.txt
    ```

    If `/tmp/jsp-sync-clobbered.txt` is non-empty: ABORT. Run `git merge --abort`, show the clobbered list to the user, and stop. The merge silently modified files only the project had changed; investigate before re-running.

16. **Generate the divergence report**:

    Write a markdown summary to `/tmp/jsp-sync-report.md`. Include these sections (omit any section whose corresponding list is empty):

    - `### Upstream changes applied` — count of paths in `/tmp/jsp-sync-upstream-only.txt`. List the first 30 paths and add "and N more" if longer.
    - `### Project changes preserved` — count of paths in `/tmp/jsp-sync-project-only.txt`. Confirm the no-clobber invariant held.
    - `### Both-changed paths requiring review` — contents of `/tmp/jsp-sync-both-changed-needs-review.txt`. Add: "Git auto-merged or the conflicts were resolved manually. Review each path before approving the PR."
    - `### Both-changed paths covered by project-owned policy` — contents of `/tmp/jsp-sync-both-changed.txt` minus the "needs review" subset. Add: "These paths were restored to the project version by the project-owned policy; no review required."
    - `### Upstream additions not applied to project-owned paths` — new files upstream added under `CLAUDE.md AGENTS.md .claude/ Makefile compose.yaml Dockerfile.dev .github/ docs/ templates/ test/seeds/ README.md config/jumpstart.yml`. Compute with:

      ```bash
      git diff --name-only --diff-filter=A "$MERGE_BASE"...jumpstart-pro/main -- \
        CLAUDE.md AGENTS.md .claude/ Makefile compose.yaml Dockerfile.dev \
        .github/ docs/ templates/ test/seeds/ README.md config/jumpstart.yml
      ```

      Add: "Adopt selectively in a follow-up if desired."

17. **Detect drift between project overrides and upstream sources**:

    Project overrides under `app/` can drift from their upstream sources under `lib/jumpstart/app/` between syncs. When upstream changes a file the project has overridden, the override silently misses the upstream improvement unless someone checks. This step surfaces that drift so reviewers see the affected overrides in the sync report.

    Find every project override whose path mirrors a file under `lib/jumpstart/app/`, then diff each override against the post-merge upstream source:

    ```bash
    comm -12 \
      <(cd app && find . -type f | sed 's|^\./||' | sort) \
      <(cd lib/jumpstart/app && find . -type f | sed 's|^\./||' | sort) \
      > /tmp/jsp-sync-override-inventory.txt

    : > /tmp/jsp-sync-override-drift.txt
    while read -r path; do
      [ -z "$path" ] && continue
      if ! diff -q "app/$path" "lib/jumpstart/app/$path" >/dev/null 2>&1; then
        echo "$path" >> /tmp/jsp-sync-override-drift.txt
      fi
    done < /tmp/jsp-sync-override-inventory.txt
    ```

    Append a new section to `/tmp/jsp-sync-report.md`:

    - `### Project overrides with drift from upstream source` — contents of `/tmp/jsp-sync-override-drift.txt`. List the first 30 paths and add "and N more" if longer. Add: "Each listed override differs from its upstream source under `lib/jumpstart/app/`. Review whether upstream's improvements should be adopted into the override; the structural-first-then-reconcile cadence described below handles this as follow-up work after the sync PR merges."

    If `/tmp/jsp-sync-override-drift.txt` is empty, omit the section.

18. **Complete the merge**:
    - Run `git commit` to finalize the merge commit.

19. **Push the working branch**:
    - Run `git push -u origin HEAD`.

20. **Hand off to the user**:
    - Report that the working branch has been pushed to `origin` and that the divergence audit is saved at `/tmp/jsp-sync-report.md`.
    - Instruct the user to open the PR with their own preferred workflow and to include the contents of `/tmp/jsp-sync-report.md` under a `## Sync audit` section in the PR body.
    - Stop. Intermediate scratch files matching `/tmp/jsp-sync-*` are cleaned up at the start of the next sync run by step 1.

**Path policy:**

| Path | Treatment |
|------|-----------|
| `app/` | Project owns. Upstream should not add files here; upstream framework additions belong under `lib/jumpstart/app/`. |
| `lib/jumpstart/app/` | Upstream owns. Framework engine overrides flow in through the divergence audit. Project edits here are drift and should move to overrides under `app/`. |
| `test/` (including `test/seeds/`) | Project owns |
| `README.md`, `CLAUDE.md`, `AGENTS.md`, `.claude/` | Project owns |
| `Makefile`, `compose.yaml`, `Dockerfile.dev`, `.github/` | Project owns |
| `docs/`, `templates/` | Project owns |
| `config/jumpstart.yml` | Project owns |
| `Gemfile` | Project version kept; upstream gem changes surfaced for opt-in |
| `Gemfile.lock` | Project version kept; regenerate with `bundle lock` after the merge commit |
| `.cursor/`, `UPGRADE.md` | Upstream-only; `UPGRADE.md` is displayed during sync, then both are removed from the worktree before commit |
| `config/database.yml`, `package.json` | Manual review during conflict resolution |
| Rails substrate (`config/` other than above, `db/`, `lib/`, `bin/`, root dotfiles, `Rakefile`, anything else) | Divergence audit: project changes preserved, upstream changes applied, both-changed paths reported for review |

**Handling deferred upstream improvements after the sync:**

When the sync surfaces both-changed paths under `lib/jumpstart/app/` and the project's edits are kept, or when the drift-detection step (step 17) reports overrides that have fallen behind upstream, address the deferred upstream changes in two follow-up phases.

Phase A (structural). For each affected path, create an override under `app/` at the matching relative path, then revert the engine-owned file in `lib/jumpstart/app/` to upstream HEAD. The in-engine generator handles the override scaffolding: `bin/rails generate jumpstart:override <app-path>`. This is a runtime no-op because `config.railties_order = [:main_app, Jumpstart::Engine, :all]` resolves the override ahead of the engine copy. Phase A lands as a single PR (or a small PR group when the change set is large), so the structural move is reviewed independently of any content changes.

Phase B (reconciliation). Per area (for example, `application/*`, `devise/*`, `notifications/*`), compare each override against the corresponding upstream source under `lib/jumpstart/app/` and adopt upstream's improvements where they don't conflict with project customizations. Translation key renames require matching updates to `config/locales/en.yml`. Phase B is one PR per area so each reconciliation is reviewable on its own.

**Example usage:**

Run the full sync (merge, commit, push):

```bash
/upstream-sync
```

Produce the divergence audit only, without merging:

```bash
/upstream-sync --report
```

**When to use:**
- Periodically to stay current with Jumpstart Pro Rails improvements.
- Before major releases to ensure the latest upstream changes are included.
- After upstream maintainers announce updates.
- With `--report`, before a planned sync to preview which paths will need review.
