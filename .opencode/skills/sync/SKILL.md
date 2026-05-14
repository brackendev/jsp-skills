---
name: sync
description: Merge Jumpstart Pro Rails (JSP) upstream changes into the project on a working branch and push it for review, preserving project customizations through a merge-base divergence audit
allowed-tools: Bash(git checkout:*), Bash(git fetch:*), Bash(git pull:*), Bash(git branch:*), Bash(git merge:*), Bash(git merge-base:*), Bash(git push:*), Bash(git add:*), Bash(git commit:*), Bash(git show:*), Bash(git diff:*), Bash(git status:*), Bash(git restore:*), Bash(git remote:*), Bash(git symbolic-ref:*), Bash(date:*), Bash(comm:*), Bash(sort:*), Bash(diff:*), Bash(grep:*), Bash(sed:*), Bash(wc:*), Bash(cat:*), Bash(rm:*), Read, AskUserQuestion
user-invocable: true
disable-model-invocation: true
---

Merge the latest Jumpstart Pro Rails (JSP) upstream changes into a project that started as a clone of the Jumpstart Pro template. The skill's first priority is to never silently overwrite project customizations. Every path that diverges between the project and upstream is classified, every both-changed path is surfaced for review, and project-only changes are verified intact before the merge commit is created.

JSP is shorthand for Jumpstart Pro Rails (https://jumpstartrails.com/), a paid SaaS Rails template distributed as a Git repository that customers clone, customize, and upgrade by merging from the upstream repository.

**Prerequisites:**

- The project has the Jumpstart Pro Rails repository configured as a Git remote named `jumpstart-pro`. Verify with `git remote -v`. If the remote is missing, add it with `git remote add jumpstart-pro <jsp-repo-url>` before running this skill.

**Arguments:** None

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
   - Run `date +%Y%m%d`.
   - Run `git checkout -b task/pull-upstream-YYYYMMDD`.

10. **Pre-merge audit**:
    - Show the user the counts: project-only, upstream-only, and both-changed (with the "needs review" subset called out).
    - Display the contents of `/tmp/jsp-sync-both-changed-needs-review.txt` so the user knows which paths Git will attempt to auto-merge.
    - Use `AskUserQuestion` to ask whether to proceed with the merge. Options: continue, or stop here so the user can inspect manually.

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

    Re-apply upstream additions under `app/` so new files (for example, new engine overrides) flow in:

    ```bash
    git diff --name-only --diff-filter=A HEAD...jumpstart-pro/main -- app/ \
      | xargs -I{} git checkout jumpstart-pro/main -- {} 2>/dev/null
    git diff --name-only --diff-filter=A HEAD...jumpstart-pro/main -- app/ \
      | xargs -I{} git add {} 2>/dev/null
    ```

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

17. **Complete the merge**:
    - Run `git commit` to finalize the merge commit.

18. **Push the working branch**:
    - Run `git push -u origin HEAD`.

19. **Hand off to the user**:
    - Report that the working branch has been pushed to `origin` and that the divergence audit is saved at `/tmp/jsp-sync-report.md`.
    - Instruct the user to open the PR with their own preferred workflow and to include the contents of `/tmp/jsp-sync-report.md` under a `## Sync audit` section in the PR body.
    - Stop. Intermediate scratch files matching `/tmp/jsp-sync-*` are cleaned up at the start of the next sync run by step 1.

**Path policy:**

| Path | Treatment |
|------|-----------|
| `app/` | Project owns; new upstream files under `app/` are re-applied so framework engine overrides flow in |
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

**Example usage:**
```bash
/jsp-skills:sync
```

**When to use:**
- Periodically to stay current with Jumpstart Pro Rails improvements.
- Before major releases to ensure the latest upstream changes are included.
- After upstream maintainers announce updates.
