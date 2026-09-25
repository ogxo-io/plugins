# Pull Request Generator - Examples

This document provides detailed examples of how to use the pr-generator skill in various scenarios.

## Example 1: Feature PR with an Issue Key

**User Request:** "Create a pull request for my OAuth changes"

**Process:**
1. Run `analyze_pr_changes.py` → Detects branch `PROJ-234-add-oauth`, 4 commits, type `feat`
2. Run `detect_pr_template.py` → No repo template found, use default
3. Generate title: `[PROJ-234] feat(auth): add OAuth2 integration with Google`
4. Generate description with Summary, Changes (grouped by area), Test Plan
5. Present to user with 3 options
6. User chooses "create automatically"
7. Push branch and run `gh pr create` with generated content

**Expected Output:** PR created with comprehensive title and description

## Example 2: Bug Fix PR without an Issue Key

**User Request:** "Help me create a PR for the null pointer fix"

**Process:**
1. Run `analyze_pr_changes.py` → Branch `fix-user-profile-crash`, 2 commits, type `fix`
2. Run `detect_pr_template.py` → Repo has template in `.github/PULL_REQUEST_TEMPLATE.md`
3. Generate title: `fix(users): prevent crash on null profile data`
4. Fill repo template with generated content
5. Present to user
6. User chooses "show me the command"
7. Display `gh pr create` command for user to run

**Expected Output:** Command ready for user to execute

## Example 3: Large Refactoring PR

**User Request:** "Generate PR description for my refactoring work"

**Process:**
1. Run `analyze_pr_changes.py` → 15 commits, type `refactor`, 800+ line changes
2. Note: Large PR (800 lines)
3. Generate title: `refactor(database): migrate to repository pattern`
4. Generate comprehensive description:
   - Summary explaining motivation
   - Detailed changes grouped by component
   - Note about no functional changes
   - Extensive test plan
   - Add "Deployment Notes" section (migration required)
5. Present to user with warning about PR size
6. Suggest breaking into smaller PRs if possible

**Expected Output:** Comprehensive PR description appropriate for large refactoring

## Presentation Format (Step 5)

When presenting generated PR content to the user, use this markdown layout — title, description, then the three automation options:

````markdown
I've analyzed your branch changes and generated a pull request. Here's the content:

---

## PR Title

```
[PROJ-234] feat(auth): add OAuth2 integration with Google
```

## PR Description

```markdown
## Summary

This PR implements JWT-based authentication to replace the current
session-based auth system. This change improves API security and
enables stateless authentication for mobile clients.

## Changes

**Authentication:**
- Add JWT token generation on successful login
- Implement token validation middleware
- Add token refresh endpoint

**Database:**
- Add user token storage table
- Create migration for auth schema changes

## Test Plan

- [ ] All unit tests pass
- [ ] Login with OAuth and verify JWT token
- [ ] Test token expiration and refresh
- [ ] Verify error handling for invalid tokens

## Related Issues

Closes #234
```

---

**Would you like me to:**
1. Just generate this content (you can copy and create PR manually)
2. Push the branch and show the `gh pr create` command
3. Create the PR automatically using GitHub CLI

Please let me know how you'd like to proceed!
````

## Edge Cases and Error Handling

### No Commits Between Branches

**Scenario:** Current branch has no commits ahead of base branch

**Detection:**
```json
"commit_analysis": {
  "total_commits": 0
}
```

**Handling:**
- Inform user: "No commits found between `current_branch` and `base_branch`"
- Ask: "Are you on the correct branch?"
- Suggest: "Make sure you've committed your changes"
- Do not proceed with PR generation

### Unpushed Branch

**Scenario:** Branch exists locally but not on remote

**Detection:**
```json
"branch_status": {
  "has_remote": false,
  "needs_push": true
}
```

**Handling:**
- Inform user: "Branch has not been pushed to remote yet"
- In Option 2 or 3: Include push command
- Example: `git push -u origin feature-branch`

### Non-Conventional Commits

**Scenario:** Some commits don't follow Conventional Commits format

**Detection:**
```json
"commit_analysis": {
  "conventional_commits": 5,
  "non_conventional_commits": 3
}
```

**Handling:**
- Still generate PR based on available conventional commits
- Use most common type among conventional commits
- If no conventional commits: Default to `chore` or analyze files to guess type
- Mention in PR description: "Note: Some commits don't follow conventional format"

### Multiple Issue Keys

**Scenario:** Branch name contains multiple issue keys or commits mention different issues

**Detection:**
- Branch: `PROJ-123-PROJ-456-combined`
- Or commits mention different issues

**Handling:**
- Use the first issue key from the branch name in title
- In "Related Issues" section, mention all detected issues
- Example: "Related to PROJ-123, PROJ-456"

### Very Large PRs

**Scenario:** PR has 1000+ line changes or 20+ files

**Detection:**
```json
"statistics": {
  "files_changed": 25,
  "total_changes": 1500
}
```

**Handling:**
- Generate PR as normal
- Add warning in output: "⚠️ This is a large PR (1500 lines, 25 files)"
- Suggest: "Consider breaking into smaller PRs for easier review"
- Add note in PR description about reviewing strategy
- Reference: See `references/pr-best-practices.md` section on "When PRs Are Too Large"

### Breaking Changes Detected

**Scenario:** Commits marked with `!` or `BREAKING CHANGE:`

**Detection:**
```json
"commit_analysis": {
  "has_breaking_changes": true
}
```

**Handling:**
- Add `!` to PR title type: `feat(api)!: restructure endpoints`
- **Always** include "Breaking Changes" section in description
- List what breaks and how to migrate
- Add ⚠️ warning emoji in description
- Reference affected commit messages for details

### No Base Branch Detected

**Scenario:** Can't determine base branch from git config

**Detection:**
- Script returns empty base branch
- Or git commands fail

**Handling:**
- Ask user: "Which branch should this PR target? (main/master/develop)"
- Wait for user response
- Re-run analysis with specified base: `--base user_choice`

### Repository Template Directory with Multiple Templates

**Scenario:** `.github/PULL_REQUEST_TEMPLATE/` contains multiple templates

**Detection:**
```json
"template_type": "directory",
"available_templates": [
  {"name": "feature_template.md"},
  {"name": "bugfix_template.md"},
  {"name": "hotfix_template.md"}
]
```

**Handling:**
- Determine PR type from commit analysis
- Match to appropriate template:
  - `feat` → feature_template.md
  - `fix` → bugfix_template.md
  - Hotfix branch → hotfix_template.md
- If unsure, ask user: "Found multiple templates. Which one? (1) feature (2) bugfix (3) hotfix"

### gh CLI Not Available

**Scenario:** User chooses automation but `gh` command not found

**Detection:**
```bash
which gh  # Returns empty
```

**Handling:**
- Inform user: "`gh` CLI not found. Please install GitHub CLI: https://cli.github.com/"
- Fall back to Option 1: Provide content for manual creation
- Show web UI instructions: "Go to GitHub → Compare & pull request"

## Common Mistakes to Avoid

### Mistake 1: Auto-Creating PRs Without User Permission

**Wrong:**
```
User: "Create a PR for my OAuth changes"
Assistant: *Runs analysis, generates content, and immediately executes `gh pr create` without asking*
```

**Correct:**
```
User: "Create a PR for my OAuth changes"
Assistant: *Runs analysis, generates content*
         *Presents markdown with three options*
         "Would you like me to:
         1. Just generate this content (you copy manually)
         2. Show the `gh pr create` command
         3. Create the PR automatically"
         *Waits for user response*
```

### Mistake 2: Skipping Analysis Scripts

**Wrong:**
```
Assistant: *Looks at git log directly, guesses at changes, generates PR based on incomplete data*
```

**Correct:**
```
Assistant: *Runs `python3 ${CLAUDE_PLUGIN_ROOT}/skills/pr-generator/scripts/analyze_pr_changes.py --pretty`*
         *Runs `python3 ${CLAUDE_PLUGIN_ROOT}/skills/pr-generator/scripts/detect_pr_template.py --pretty`*
         *Generates PR based on comprehensive analysis*
```

### Mistake 3: Using Past Tense in PR Titles

**Wrong:**
- `[PROJ-234] feat(auth): added OAuth2 integration`
- `fix: updated user profile crash handling`

**Correct:**
- `[PROJ-234] feat(auth): add OAuth2 integration`
- `fix: prevent user profile crash`

### Mistake 4: Not Including Issue Keys

**Wrong:**
```
Branch: PROJ-234-oauth-integration
Generated Title: feat(auth): add OAuth2 integration
```

**Correct:**
```
Branch: PROJ-234-oauth-integration
Generated Title: [PROJ-234] feat(auth): add OAuth2 integration
```

### Mistake 5: Generating Without Analyzing First

**Wrong:**
```
Assistant: *Immediately generates PR based on current understanding*
```

**Correct:**
```
Assistant: *First runs analysis scripts*
         *Then generates PR using structured data*
```

### Additional Mistakes to Avoid

6. **Don't assume base branch** - Detect from git config
7. **Don't skip test plan** - Always include comprehensive testing
8. **Don't include unstaged changes** - Only committed changes
9. **Don't forget to push branch** - Check and handle unpushed branches
