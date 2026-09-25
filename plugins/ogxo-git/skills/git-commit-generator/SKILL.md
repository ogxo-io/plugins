---
name: git-commit-generator
description: Generate professional commit messages following Conventional Commits format from staged git changes. Use when the user wants to write, generate, or review a commit message, or asks to commit staged changes.
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(git rev-parse:*), Bash(git commit:*), Bash(python3:*), Read, Glob, Grep
effort: low
---

# Git Commit Message Generator

## Rules

These reflect how the user works and hold even when the user says "just commit it":

- Don't run `git add`; the user stages manually to track what they've reviewed. If nothing is staged, list the changed files and ask them to stage (Step 6).
- No AI attribution or co-author trailers unless the user names a co-author (Step 6).
- Use plain `git commit`; don't pass `--no-gpg-sign` or `--no-verify` — a GPG passphrase prompt is expected (Step 9).
- Show the full message and wait for an explicit yes before committing (Step 9).

## Overview

This skill generates professional, descriptive commit messages by analyzing **staged** git changes. It follows the Conventional Commits specification with project-specific rules for issue-key references, co-author policy, and file filtering.

## Workflow

### Step 1: Pre-Commit Validation

If the project defines a fast lint/format check, run it — automated tools catch issues you may miss. Look in priority order and use the first that exists:

1. **Makefile** targets (`make lint`, `make format`, `make check`)
2. **package.json** scripts (`npm run lint`, `npm run format`)
3. **Language tools** (eslint/prettier, black/flake8/mypy, gofmt/go vet, cargo fmt/clippy)
4. **Pre-commit hooks** (`pre-commit run`, `.git/hooks/pre-commit`)

Respect the project's preferred tooling — don't run `eslint` directly if `npm run lint` exists.

**If checks fail:** show the errors and suggest the fix command (`make format`, `npm run lint:fix`, `eslint --fix .`, `black .`), and don't commit until they pass. You can still draft the message if the user only asked for one.

For the full detection catalog and per-language commands, see [references/troubleshooting.md](references/troubleshooting.md).

### Step 2: Analyze Git State

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/skills/git-commit-generator/scripts/analyze_changes.py
```

The script returns JSON with the branch name (and any issue key), staged/unstaged/untracked files, file categorization, change stats, and recent commit messages for style reference. It does **not** include diff content — also run `git diff --staged` to read the actual changes before Step 3.

**If the script is unavailable,** fall back to manual commands:

```bash
git status                       # Overall repository state
git diff --staged                # Full diff of staged changes
git diff --staged --stat         # Summary statistics
git log -5 --oneline             # Recent commit style
git rev-parse --abbrev-ref HEAD  # Current branch name
```

### Step 3: Review and Categorize Changes

From the **staged** changes, determine: what changed, why (the problem solved or feature added), the impact, and the affected scope. Use file categories to pick a scope — code → component/module name (auth, api, database), tests → `test`, docs → `docs`, config → `config`/`ci`/`build`. For mixed categories, choose the primary focus.

### Step 4: Determine Commit Type

- **feat** — new feature   **fix** — bug fix   **perf** — performance
- **refactor** — restructuring, no behavior change   **docs** — docs only
- **test** — tests   **style** — formatting   **chore** — maintenance
- **ci** — CI/CD pipeline   **build** — build system or dependencies

Decision order: adds functionality → `feat`; fixes a bug → `fix`; improves performance → `perf`; docs only → `docs`; restructuring → `refactor`; test-related → `test`; CI/build → `ci`/`build`; otherwise → `chore`.

### Step 5: Craft the Message

**Subject:** `<type>(<scope>): <description>` — imperative mood ("add" not "added"), aim for ≤50 chars (72 is the hard limit), description case matching the repo's recent commit subjects (lowercase if there's no clear convention), no period.

**Body** (recommended for non-trivial changes): explain WHY the change was made and its impact, wrap at 72 chars, bullet related changes. Keep it clean — no line counts, file sizes, or technical metrics.

**Footer** (optional): issue references (`Closes #123`), `BREAKING CHANGE: <description>`, and co-authors ONLY if explicitly requested.

### Step 6: Apply Project Rules

**Co-authors / AI attribution:**
- **Never** add `Co-authored-by:` automatically — this includes AI attribution.
- **Never** add `Co-Authored-By: Claude <noreply@anthropic.com>` or "Generated with Claude Code" — commits reflect human authorship.
- Add a co-author only when the user **explicitly requests** a specific person; ask for name and email if not provided.
- The user's CLAUDE.md may forbid co-authors entirely — respect that.

**Issue-key references:**
- If the branch name contains an issue key (e.g. `PROJ-123-feature`), extract it but **do NOT** add it automatically.
- Include an issue reference only if the user explicitly requests it.

**Staging & file filtering:**
- **Never run `git add` or stage files yourself** — the user stages manually to track what has been reviewed. Present the list of changed files and ask the user to stage the ones they want committed.
- Describe **only staged files** (`git diff --staged`). Never mention unstaged or untracked files.
- If the staged files include planning or scratch artifacts (`plan.md`, task notes), point them out before committing.

### Step 7: Validate the Message

Confirm: subject ≤50 chars where possible (never over 72), imperative mood, case after the colon matches repo history (lowercase if no clear convention), no period; type and scope appropriate; body explains WHY, not just WHAT; only staged files referenced; no co-author unless requested; breaking changes marked; message accurately reflects the change.

### Step 8: Present the Message

Show the message in a code block for easy copying:

````markdown
```
type(scope): brief description

Body paragraph explaining why this change was made and its impact.

- Related change 1
- Related change 2

Closes #123
```
````

### Step 9: Execute Commit (If Requested)

If the user asks you to execute the commit (not just generate it), show the message and get approval before committing — even when the user says "just commit it", because they review every message before it lands.

**Part 1 — Present and confirm (always first):**
1. Show the complete commit message in a code block.
2. Ask explicitly: **"Should I execute this commit?"**
3. **Wait** for an explicit "yes" — do not proceed without it.

**Part 2 — Execute (only after approval):**
4. Run plain `git commit` with **no flags** — the user's system handles GPG signing automatically.

- **Never** use `--no-gpg-sign` — it bypasses the user's security configuration.
- **Never** use `--no-verify` — it bypasses pre-commit hooks.
- If GPG signing is configured, a passphrase popup is expected — let it happen.

```bash
# Multi-line message (use a heredoc)
git commit -m "$(cat <<'EOF'
type(scope): brief description

Body paragraph explaining the change.
EOF
)"

# Single-line message
git commit -m "type(scope): brief description"
```

## Reference Documentation

- **[references/commit-guidelines.md](references/commit-guidelines.md)** — Conventional Commits format, types, scope, writing style, breaking changes, and project rules. Load for format clarification.
- **[references/examples.md](references/examples.md)** — worked commit examples, edge cases (breaking changes, mixed types, merge commits), and common wrong-vs-correct mistakes.
- **[references/troubleshooting.md](references/troubleshooting.md)** — pre-commit tool detection and per-language commands, failing lint checks, script fallback, unclear changes, GPG/hook issues, large diffs.
- **scripts/analyze_changes.py** — structured JSON git analysis (Step 2); run via the absolute path above.
- **assets/commit-template.txt** — commit message template for guided or manual authoring.

## Workflow Decision Tree

```
Is the user asking to:
├─ Generate a message only?
│  └─ Run Steps 1–8; present in a code block, do NOT execute.
├─ Review and confirm before committing?
│  └─ Run Steps 1–8, then ask "Should I execute this commit?"; wait for yes.
├─ Commit directly ("just commit it")?
│  └─ Run Steps 1–8, present the message, STILL ask for confirmation.
└─ Fix a previous commit message?
   └─ Not pushed → offer git commit --amend. Already pushed → warn about rewriting history.
```

**Default:** if unsure, generate and present the message for review without executing.

## Quick Reference Checklist

Complete these in order for every commit request:

- [ ] **Step 1** Run the project's lint/format check if it has one; don't commit while it fails.
- [ ] **Step 2** Analyze git state (staged files, diff, branch, recent commits).
- [ ] **Step 3** Review and categorize the staged changes.
- [ ] **Step 4** Determine the commit type.
- [ ] **Step 5** Craft the message (subject, body, footer).
- [ ] **Step 6** Apply project rules — no auto co-authors, no auto issue refs, don't stage, flag staged plan files.
- [ ] **Step 7** Validate format and accuracy.
- [ ] **Step 8** Present the message in a code block.
- [ ] **Step 9** Execute only if requested — present and ask "Should I execute this commit?" first; never `--no-gpg-sign` or `--no-verify`.
