# Git Commit Message Generator - Examples

This document provides detailed examples of how to use the git-commit-generator skill in various scenarios.

## Example 1: Feature Addition

**User Request:** "I've added JWT authentication to the API. Can you create a commit message?"

**Process:**
1. Run analysis: `python3 ${CLAUDE_PLUGIN_ROOT}/skills/git-commit-generator/scripts/analyze_changes.py`
2. Review staged files: `src/auth/jwt.js`, `src/middleware/auth.js`, `tests/auth.test.js`
3. Determine type: `feat` (new feature)
4. Determine scope: `auth` (authentication module)
5. Draft message explaining what and why

**Generated Message:**
```
feat(auth): add JWT authentication with token refresh

Implements JWT-based authentication system with:
- Token generation on successful login
- Middleware for request authentication
- Automatic token refresh mechanism
- Secure token storage in HTTP-only cookies

This improves API security and enables stateless authentication
across distributed services.

Closes #234
```

## Example 2: Bug Fix

**User Request:** "Fixed a bug where null user profiles were crashing the app. Write the commit."

**Process:**
1. Check staged changes: `git diff --staged`
2. Identify files: `src/users/profile.js`, `tests/users/profile.test.js`
3. Type: `fix` (bug correction)
4. Scope: `users` or `api`
5. Explain the fix and its importance

**Generated Message:**
```
fix(users): prevent crash on null profile data

Add null checks before accessing nested profile properties.
This prevents application crashes when user profile is incomplete
or contains null values.

- Validate profile object exists before access
- Add default values for missing fields
- Add tests for null profile scenarios

Fixes #456
```

## Example 3: Refactoring with Multiple Files

**User Request:** "I refactored the database layer. Generate a commit message."

**Process:**
1. Analyze changes: Multiple files in `src/database/`
2. Review diff to understand what changed structurally
3. Type: `refactor` (code restructuring)
4. Scope: `database`
5. List the changes and benefits

**Generated Message:**
```
refactor(database): migrate to repository pattern

Extracts database queries from controllers into dedicated
repository classes:
- UserRepository for user data operations
- OrderRepository for order management
- ProductRepository for product catalog

Benefits:
- Improved testability through interface-based design
- Reduced code duplication across controllers
- Easier to switch database implementations
- Clearer separation of concerns

No user-facing changes. All tests passing.
```

## Example 4: Issue-Key Branch Integration

**User Request:** "Commit these changes" (on branch `PROJ-789-add-search`)

**Process:**
1. Detect branch name: `PROJ-789-add-search`
2. Extract issue key: `PROJ-789`
3. Ask user: "Should I include the issue reference (PROJ-789) in the commit?"
4. If yes, add to footer: `Closes PROJ-789`
5. If no, omit the reference

**Generated Message (if user says yes):**
```
feat(search): add full-text search with Elasticsearch

Implements search functionality with:
- Elasticsearch integration for fast queries
- Relevance scoring and highlighting
- Faceted filtering by category
- Pagination support

Closes PROJ-789
```

## Example 5: Documentation Only

**User Request:** "Updated the README with Docker setup instructions. Create commit."

**Process:**
1. Check staged: `README.md`
2. Type: `docs` (documentation only)
3. Scope: `readme` or omit
4. Describe what documentation was added

**Generated Message:**
```
docs(readme): add Docker setup instructions

Includes step-by-step guide for:
- Docker Compose configuration
- Environment variable setup
- Database initialization
- Common troubleshooting steps

Makes it easier for new developers to set up local environment.
```

## Example 6: Pre-Commit Validation Flow

**User Request:** "Create a commit message for my changes"

**Process:**
1. Check for project linting/formatting tools:
   ```bash
   # Detect JavaScript project
   cat package.json | grep -E '"lint"|"format"'
   ```
2. Run quality checks first:
   ```bash
   npm run lint
   # Output: ESLint found 3 errors
   ```
3. Inform user: "Lint checks failed with 3 errors. Please fix these first:"
   - Show the errors
   - Suggest: "Run `npm run lint:fix` to auto-fix"
4. Wait for user to fix issues
5. After fixes, re-check:
   ```bash
   npm run lint
   # Output: All checks passed ✓
   ```
6. Now proceed with git analysis and commit message generation

**Response to User:**
```
Before generating the commit message, I found lint errors in the staged files:

src/components/Button.js
  12:5  error  Missing semicolon  semi
  23:10 error  'props' is defined but never used  no-unused-vars

Please run `npm run lint:fix` to auto-fix these issues, then I'll generate the commit message.
```

## Edge Cases and Error Handling

### No Staged Changes

**Problem:** User asks for commit message but no files are staged.

**Solution:**
1. Check `git diff --staged` - if empty, no staged changes
2. Inform the user: "No files are currently staged." Present the list of changed files (`git status --short`) and ask which they want to stage.
3. Do NOT stage on their behalf — the user stages manually. Suggest `git add <files>` (or `git add -p` for hunk-by-hunk selection) for them to run, then continue once files are staged.

### Mixed Change Types

**Problem:** Staged changes include both features and bug fixes.

**Solution:**
1. Identify the multiple types of changes
2. Recommend: "I notice both feature additions and bug fixes. It's better to:"
   - "Commit them separately for clearer history"
   - "Choose the primary change type if they're closely related"
3. Ask user: "Would you like me to generate separate commits, or combine them with the primary type?"

### Breaking Changes

**Problem:** Changes modify public API or behavior.

**Solution:**
1. Detect breaking changes from diff or user indication
2. Ask user: "These changes appear to break backward compatibility. Should I mark this as a breaking change?"
3. If yes, add `!` to type: `feat(api)!:` and add `BREAKING CHANGE:` footer
4. Include migration guidance in body

### Large Refactoring

**Problem:** Many files changed in a large refactoring.

**Solution:**
1. Focus on the overall goal, not individual file changes
2. Use bullet points to list the major changes
3. Emphasize "No user-facing changes" if applicable
4. Keep description focused on "why" not "what"

### Merge Commits

**Problem:** User is on a merge commit with conflicts.

**Solution:**
1. Detect merge commit: check for `MERGE_HEAD`
2. Inform user: "This appears to be a merge commit. Git will generate a default message."
3. Ask: "Would you like a custom merge commit message?"
4. If yes, format: `Merge branch 'feature-branch' into main`

## Common Mistakes (Wrong vs Correct)

These illustrate the project rules enforced in Steps 6 and 9 of the workflow.

### Mistake 1: Auto-Adding Co-Authors

- **Wrong:** generating a commit with `Co-Authored-By: Claude <noreply@anthropic.com>`.
- **Correct:** generating the commit with no co-author footer.
- **Why:** co-authors are added only when the user explicitly requests them, and AI attribution is never appropriate. Check the user's CLAUDE.md for co-author policy.

### Mistake 2: Using `--no-gpg-sign` to Bypass Signing

- **Wrong:** running `git commit --no-gpg-sign -m "message"`.
- **Correct:** running `git commit -m "message"` and letting the system handle GPG.
- **Why:** `--no-gpg-sign` bypasses the user's security configuration. If signing is enabled, the system prompts for the passphrase automatically.

### Mistake 3: Committing Without Showing the Message First

- **Wrong:** immediately running `git commit -m "feat: add feature"`.
- **Correct:** showing the message in a code block, asking "Should I execute this commit?", and waiting for confirmation.
- **Why:** the user must review and approve the message before it is committed.

### Mistake 4: Including Unstaged Files

- **Wrong:** describing changes from both staged AND unstaged files.
- **Correct:** describing only staged changes (`git diff --staged`).
- **Why:** the message should reference only what will actually be committed.

### Mistake 5: Committing Plan Files Without Mentioning Them

- **Wrong:** committing a staged `plan.md` alongside source code without comment.
- **Correct:** pointing out the staged planning artifact and asking whether it belongs in this commit.
- **Why:** plan files (`plan.md`, task notes) are usually working artifacts, not deliverables. Don't run `git add` or unstage anything yourself — the user stages manually.
