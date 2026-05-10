---
name: ship
description: Branch, commit, push, create PR, and label in one workflow
argument-hint: "[issue-number] [pr-title]"
allowed-tools: Bash(make lint-fix:*), Bash(make test-all:*), Bash(make up:*), Bash(make ps:*), Bash(git status:*), Bash(git add:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git checkout:*), Bash(git push:*), Bash(gh pr create:*), Bash(gh pr edit:*), Bash(gh label list:*), mcp__playwright__browser_navigate, mcp__playwright__browser_screenshot, mcp__playwright__browser_click, mcp__playwright__browser_type, mcp__playwright__browser_close, AskUserQuestion
user-invocable: true
disable-model-invocation: true
---

Complete feature workflow from branch creation to PR with labels:

**Prerequisites:**
- Test database must be seeded with test user for screenshot authentication
- Run `make setup` (first time) to seed database with test fixtures
- Expected test user: Email and password accessible for Playwright login flow
- Rails server must be startable on `https://localhost:3001`

**Arguments** (both optional):
- `$1` = issue number (if provided, creates branch `feature/$1-$2` and references in PR body with "Closes #$1")
- `$2` = PR title (also used for branch name; if omitted, generate from commit messages and changes)
- PR body is **always auto-generated** from template by analyzing git diff and commits

**Steps**:

1. **Run quality checks FIRST**:
   - Ensure Rails server running: Check `make ps`, start with `make up -d` if needed
   - Run `make lint-fix` to fix any linting issues
   - Run `make test-all` to ensure all tests pass
   - **If either fails: Exit immediately with error message. No git operations performed.**
   - If both pass: Any lint fixes will be included in the commit

2. **Check current state**:
   - Run `git status` to see current branch and changes
   - Run `git branch --show-current` to get current branch

3. **Branch creation** (if on master):
   - If on master with issue + title: Create `feature/$1-$2` (e.g., `feature/161-add-ssl-guide`)
   - If on master with issue only: Create `feature/$1-{generated-title}` (generate title from changes)
   - If on master with no args: Create `feature/{generated-title}` (e.g., `feature/add-user-authentication`)
   - If already on a feature branch: Continue on current branch (no new branch created)

4. **Capture UI screenshots** (if view files changed):
   - Run `git diff HEAD --name-only` to find changed view files (`**/*.html.erb`)
   - Skip partials (files starting with `_`)
   - **If view files are detected, ask the user before capturing:**
     Use AskUserQuestion with:
     - header: "Screenshots"
     - question: "View files changed. Capture screenshots for the PR?"
     - options:
       - label: "Yes (Recommended)"
         description: "Navigate to changed pages, capture screenshots, include in PR body"
       - label: "Skip screenshots"
         description: "Create PR without capturing screenshots"
   - **If user chooses "Skip screenshots", proceed to step 5**
   - Infer routes from file paths using heuristics:
     - `app/views/{controller}/{action}.html.erb` → `/{controller}/{action}`
     - `app/views/{controller}/show.html.erb` → `/{controller}/1` (use test fixture ID)
     - `app/views/{controller}/edit.html.erb` → `/{controller}/1/edit`
     - `app/views/static/index.html.erb` → `/`
     - Skip layout files (`app/views/layouts/**`)
   - Get current branch name for organizing screenshots
   - For each inferred route:
     - Navigate to `https://localhost:3001{route}` using Playwright
     - Handle authentication: Navigate to `/users/sign_in` first, fill credentials (requires seeded test user)
     - Capture full-page screenshot
     - Save as `screenshots/{branch-name}/{route-slug}.png` (e.g., `screenshots/feature-161-add-dashboard/users-1.png`)
   - Stage screenshots: `git add screenshots/`
   - If no view files changed or Playwright unavailable: Skip this step gracefully

5. **Commit changes**:
   - Run `git diff` to see unstaged changes
   - Run `git log -5 --oneline` to understand commit style
   - Stage all relevant files (skip secrets like .env)
   - Create commit with imperative mood message
   - Format: "Add/Fix/Refactor description"

6. **Push to remote**:
   - Push with `git push -u origin HEAD`

7. **Create PR**:
   - Run `git log origin/master..HEAD --oneline` for commits
   - Run `git diff origin/master...HEAD` for full changes
   - Get current branch name: `git branch --show-current` (needed for organizing screenshots in PR body)

   **PR Title:**
   - If `$2` provided: Use as-is in imperative mood (e.g., "Add SSL troubleshooting guide")
   - If `$2` omitted: Generate from commit messages in imperative mood

   **PR Body (auto-generated from template):**
   - Analyze commits and diff to fill template sections
   - Write all descriptions in imperative mood
   - **Critical**: Describe changes from the perspective of `master → branch`, not internal refactoring steps within the branch
     - ❌ Wrong: "Removed unnecessary heading from detail page" (if that heading was only added in an earlier commit of the same branch)
     - ✅ Correct: "Add comprehensive detail page layout with delivery information panels"
     - Focus on the net effect of merging the branch into master, not intermediate commits
   - **Important**: Only include sections that have content. Omit empty sections.
   - Template structure:

```markdown
## Description
[Auto-generated: Summarize changes from git diff and commits]

## Related Issue
[If $1 provided: "Closes #$1", otherwise omit this section entirely]

## Motivation and Context
[Auto-generated: Infer from commit messages and changes]

## Screenshots
[Auto-detect NEW screenshots added in this PR by checking `git diff origin/master...HEAD --name-only` for files in `screenshots/{branch-name}/`]
[If new screenshots found, include them below with descriptive section headers and names inferred from route/filename]
[Use GitHub blob URLs with ?raw=true for proper rendering in private repositories]
[Format: Use sections with headers for organization]
```markdown
### [Descriptive Section Name]
![Description](https://github.com/{owner}/{repo}/blob/{branch}/screenshots/{branch-name}/{filename}.png?raw=true)
```
[Get repo owner/name: `gh repo view --json nameWithOwner --jq '.nameWithOwner'` returns "Owner/Repo"]
[Get branch name: `git branch --show-current`]
[Example:]
```markdown
### Dashboard
![Dashboard](https://github.com/Final-Intentions/final-intentions-rails/blob/feature/161-add-dashboard/screenshots/feature-161-add-dashboard/dashboard.png?raw=true)

### User Profile
![User Profile](https://github.com/Final-Intentions/final-intentions-rails/blob/feature/161-add-dashboard/screenshots/feature-161-add-dashboard/users-1.png?raw=true)
```
[If no new screenshots added in this PR: Omit this entire section]
```

   - Create with `gh pr create --title "..." --body "..."` using HEREDOC

8. **Add labels**:
   - Run `gh label list` to see available labels
   - Analyze the changes to determine appropriate labels (e.g., "enhancement", "bug", "documentation")
   - **Ask user to confirm labels before applying:**
     Use AskUserQuestion with:
     - header: "Labels"
     - question: "Apply these labels to the PR?"
     - multiSelect: true
     - options: (dynamically populate from inferred labels, e.g.):
       - label: "enhancement"
         description: "New feature or improvement"
       - label: "documentation"
         description: "Documentation changes"
       - label: "bug"
         description: "Bug fix"
   - Add confirmed labels with `gh pr edit <pr-number> --add-label "label1" --add-label "label2"`

9. **Show PR URL** for review

**Example usage**:
```bash
/jsp-skills:ship 161 Add SSL troubleshooting guide  # With issue + PR title
/jsp-skills:ship 161                                 # With issue only (generates title from commits)
/jsp-skills:ship                                     # No arguments (generates branch name, title, everything)
```

**What gets auto-generated:**
- **Branch name:** From title or commits
- **Commit message:** From analyzing staged changes (imperative mood: "Add feature" not "Added feature")
- **PR title:** From argument or commits (imperative mood)
- **PR body:** Always generated from template by analyzing diff/commits (imperative mood)
- **Labels:** Suggested based on change analysis
- **Screenshots:** Automatically captured for changed view files and referenced in PR body

**Screenshot Management:**
- Screenshots organized by branch: `screenshots/{branch-name}/`
- Committed with the PR for permanent reference
- After PR merged: Delete branch screenshot directory to prevent bloat
- Periodic cleanup: Remove directories for merged/deleted branches monthly
- Example cleanup: `rm -rf screenshots/feature-161-*` (after PR #161 merged)
