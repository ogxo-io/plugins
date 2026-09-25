---
name: pr-generator
description: Generate PR titles and descriptions by analyzing commits and file changes. Detects Thryx issue keys and PR templates. Use when creating or drafting a pull request.
allowed-tools: Bash(git log:*), Bash(git diff:*), Bash(git status:*), Bash(python3:*), Bash(gh pr:*), Read, Glob, Grep
effort: low
---

# PR Generator

## Rules

- Base the title and description on the analysis scripts' output and the repository's PR template (Steps 1–2); templates often carry required sections.
- Present the generated content and the three options, then wait for the user's choice. Pushing and running `gh pr create` happen only when the user picks Option 3, because creating a PR is visible to the whole team.

## Overview

This skill generates comprehensive, professional pull request titles and descriptions by analyzing all commits and file changes on the current branch versus the base branch. It extracts issue keys from branch names, categorizes changes, and follows repository-specific PR templates when available.

## Workflow: Generating Pull Requests

### Step 1: Analyze Branch Changes

Run the analysis script to gather branch info, commits, file changes, and status:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/skills/pr-generator/scripts/analyze_pr_changes.py --pretty
```

**Output (JSON):** branch info (current/base, plus the issue key extracted from the branch name, e.g. `PROJ-123` from `PROJ-123-feature-branch`); commit analysis (parsed Conventional Commits types/scopes/subjects, most common type, scope frequency, breaking-change detection, counts); file changes (added/modified/deleted/renamed, categorized as code/tests/docs/config/styles/build/ci, with insertion/deletion stats); and branch status (has remote tracking, needs push).

### Step 2: Detect PR Template

Run this every time — repository templates often have required sections that must be included.

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/skills/pr-generator/scripts/detect_pr_template.py --pretty
```

Checks common locations: `.github/PULL_REQUEST_TEMPLATE.md`, `.github/PULL_REQUEST_TEMPLATE/`, `.github/pull_request_template.md`, `PULL_REQUEST_TEMPLATE.md`, `docs/PULL_REQUEST_TEMPLATE.md`.

- **When a template is found:** parse its sections (Summary, Changes, Test Plan, etc.), use its structure, fill placeholders with generated content.
- **When none is found:** use `assets/pr-template-default.md` — comprehensive sections (Summary, Changes, Test Plan, Related Issues) plus optional sections by change type (Breaking Changes, Performance, Security, etc.).

### Step 3: Generate PR Title

Generate a Conventional Commits title using the **most common commit type** from the analysis.

**Format with an issue key (when detected):** `[PROJ-123] <type>(<scope>): <description>`
**Format without an issue key:** `<type>(<scope>): <description>`

**Components:**
- **Issue-key prefix** — include the issue extracted from the branch name as `[PROJ-123]`, unless the repo's recent PR titles or the user's instructions use a different convention.
- **Type** (required) — `commit_analysis.most_common_type` (`feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `ci`, `build`, `perf`).
- **Scope** (optional) — summarize from `commit_analysis.unique_scopes`; omit when changes span unrelated areas.
- **Description** (required) — imperative mood ("add"/"fix", not "added"/"fixed"), under 50 chars excluding the issue-key prefix, specific and descriptive.

**Examples:**
- Feature with an issue key — branch `PROJ-234-oauth-integration`, type `feat`, scopes auth/database → `[PROJ-234] feat(auth): add OAuth2 integration with Google`
- Bug fix — branch `fix-null-pointer`, type `fix`, scope api → `fix(api): prevent null pointer in user endpoint`
- Multiple scopes — type `refactor`, scopes auth/database/middleware → `refactor: migrate to token-based authentication` (omit scope when changes span unrelated areas)

### Step 4: Generate PR Description

**4a. Load template:** if a repository template exists, get its content with `python3 ${CLAUDE_PLUGIN_ROOT}/skills/pr-generator/scripts/detect_pr_template.py --content-only`; otherwise use `${CLAUDE_PLUGIN_ROOT}/skills/pr-generator/assets/pr-template-default.md`.

**4b. Fill sections:**
- **Summary** (always required) — 2-3 sentences: what changed (high-level), why (motivation), and impact on users/system.
- **Changes** — grouped by logical area using scopes and file categories from the analysis.
- **Test Plan** — automated tests, manual testing steps, and edge cases.
- **Related Issues** — link tracker and GitHub issues with closing keywords (`Closes #234`).
- **Optional** — Breaking Changes, Performance Impact, Security Considerations, Deployment Notes (when applicable).

Leave out file counts, line counts, and technical metrics — reviewers see those in the diff. For per-section format and generation approach, see [section-templates.md](references/section-templates.md).

### Step 5: Present PR Content to User

Present the title and description in markdown for easy copying, then offer three options:

```markdown
I've analyzed your branch changes and generated a pull request:

## PR Title
`[PROJ-234] feat(auth): add OAuth2 integration with Google`

## PR Description
<generated description — Summary, Changes, Test Plan, Related Issues>

**Would you like me to:**
1. Just generate this content (you copy and create the PR manually)
2. Show the `gh pr create` command (and the push command, if needed) for you to run
3. Create the PR automatically using GitHub CLI
```

For a fully worked presentation example, see [examples.md](references/examples.md) ("Presentation Format").

### Step 6: Ask User for Next Steps

Present all three options and wait for the user to choose; don't assume Option 3, because creating a PR is visible to the team and needs the user's consent.

- **Option 1 — Generate only:** user copies the content and creates the PR via the GitHub UI. Best for users who prefer manual control.
- **Option 2 — Prepare command:** show `git push -u origin <branch>` (if needed) and the `gh pr create` command for the user to run. Best for users who want to review before executing.
- **Option 3 — Full automation:** push the branch if needed, run `gh pr create`, and return the PR URL. Best for users who want immediate creation.

If `branch_status.needs_push` is true, tell the user the branch needs pushing before Option 2 or 3.

### Step 7: Execute User's Choice

**Option 1 (Generate only):** content already provided in Step 5 — no further action.

**Option 2 (Show command):** if the branch needs pushing, show `git push -u origin <branch>` first, then the create command:

```bash
gh pr create --title "[PROJ-234] feat(auth): add OAuth2 integration" --body "$(cat <<'EOF'
<PR description from Step 5>
EOF
)"
```

**Option 3 (Full automation):** push if needed, create the PR with the Step 5 title/description, then report the URL:

```bash
git push -u origin <branch>   # only if needs_push

gh pr create \
  --title "[PROJ-234] feat(auth): add OAuth2 integration with Google" \
  --body "$(cat <<'EOF'
<PR description from Step 5>
EOF
)" \
  --base <branch.base from Step 1>

echo "✅ Pull request created: [PR URL from gh output]"
```

Don't stage or commit on the user's behalf; this workflow only pushes the current branch and creates the PR.

## Reference Documentation

- **`scripts/analyze_pr_changes.py`** — branch/commit/file analysis (Step 1). Extra flags: `--base <branch>` to set the base explicitly; omit `--pretty` for raw JSON to stdout.
- **`scripts/detect_pr_template.py`** — template detection (Step 2). `--content-only` prints just the template body.
- **`assets/pr-template-default.md`** — default template used when the repo has none; substitute `{summary_text}`, `{changes_list}`, `{test_plan}`, and `{related_issues}` with generated content.
- **[references/section-templates.md](references/section-templates.md)** — per-section templates and generation approach. Read when filling Summary/Changes/Test Plan/optional sections (Step 4).
- **[references/pr-best-practices.md](references/pr-best-practices.md)** — title/description conventions, PR size guidelines, author checklist, and common mistakes. Read when deciding what to include or handling large/breaking-change PRs.
- **[references/examples.md](references/examples.md)** — full scenario walkthroughs, the Step 5 presentation format, nine edge cases (no commits, unpushed branch, non-conventional commits, multiple issue keys, very large PRs, breaking changes, no base branch, multiple templates, `gh` unavailable), and Wrong/Correct mistake patterns. Read for examples or to handle a specific edge case.

## Best Practices

**Title:** include the detected issue key, use the most common commit type, keep the description under 50 chars (excluding the issue-key prefix), be specific ("add OAuth2 integration" over "add authentication"), and use imperative mood.

**Description:** focus on "why" not just "what", group changes by component (not chronologically), write a test plan covering edge cases and manual steps, link all tracker/GitHub issues, and add reviewer context for complex decisions.

**Interaction & safety:** always analyze before generating (don't guess); always run template detection; present the three options and let the user choose; warn about edge cases (large PRs, breaking changes); return the PR URL after creation.

**Error prevention:** verify `total_commits > 0`; handle unpushed branches; fall back to the default template if the repo template has issues; degrade gracefully on non-conventional commits; check `gh` CLI availability before automation.

## Common Mistakes to Avoid

The most costly mistake is creating a PR before the user chooses Option 3. Other frequent mistakes: skipping the analysis scripts, using past tense in titles, omitting a detected issue key, generating before analyzing, assuming the base branch, skipping the test plan, including unstaged changes or metrics, and forgetting to push the branch.

For Wrong/Correct examples of each, see [references/examples.md](references/examples.md) ("Common Mistakes to Avoid").

## Quick Reference Checklist

When a user wants to create a PR, complete these steps in order:

- [ ] **Step 1:** Run `analyze_pr_changes.py --pretty`
- [ ] **Step 2:** Run `detect_pr_template.py --pretty`
- [ ] **Step 3:** Generate the title using the most common commit type
- [ ] **Step 4:** Generate the description using the template
- [ ] **Step 5:** Present the content in markdown
- [ ] **Step 6:** Ask for next steps (generate only / show command / auto-create)
- [ ] **Step 7:** Execute the user's choice
