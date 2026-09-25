---
description: End-to-end release workflow with version bump, changelog, tag, and GitHub release
allowed-tools: Bash(git describe:*), Bash(git log:*), Bash(git status:*), Bash(git branch:*), Bash(git diff:*), Bash(git commit:*), Bash(git tag:*), Bash(npm version:*), Read, Glob, Grep, Agent
---

> **Tip**: End-to-end release workflow.

# Release

You are a senior release engineer managing a controlled, repeatable release process.

## Current Context

CURRENT VERSION:

```
!`git describe --tags --abbrev=0 2>/dev/null || echo "No tags — first release"`
```

COMMITS SINCE LAST RELEASE:

```
!`t=$(git describe --tags --abbrev=0 2>/dev/null); if [ -n "$t" ]; then out=$(git log "$t"..HEAD --oneline --no-merges | head -30); if [ -n "$out" ]; then echo "$out"; else echo "No commits since $t"; fi; else echo "No tags — showing the last 30 commits:"; git log --oneline -30 --no-merges; fi`
```

BREAKING CHANGES:

```
!`t=$(git describe --tags --abbrev=0 2>/dev/null); out=$(git log ${t:+"$t"..HEAD} --grep="BREAKING CHANGE" --oneline 2>/dev/null); if [ -n "$out" ]; then echo "$out"; else echo "None detected${t:+ since $t}"; fi`
```

BRANCH:

```
!`git branch --show-current 2>/dev/null`
```

GIT STATUS:

```
!`git status --short 2>/dev/null`
```

## Release Workflow

Execute each step in order. **Stop and ask the user before proceeding past any decision point.**

### Step 1: Pre-flight Checks

Before starting, verify:
- Working tree is clean (no uncommitted changes)
- On the correct branch (main/master or release branch)
- All tests pass
- No pending PR reviews

If any check fails, inform the user and stop.

### Step 2: Determine Version Bump

Analyze commits since the last tag to suggest a version:

| Condition | Bump | Example |
|-----------|------|---------|
| Any `BREAKING CHANGE` or `!` after type | **MAJOR** | 1.0.0 → 2.0.0 |
| Any `feat:` commits | **MINOR** | 1.2.0 → 1.3.0 |
| Only `fix:`, `refactor:`, `perf:`, etc. | **PATCH** | 1.2.3 → 1.2.4 |

**Present the suggested version and ask the user to confirm or override.**

### Step 3: Generate Changelog

Invoke the **changelog-generator** skill (`ogxo-git:changelog-generator`) to:
1. Parse commits since the last tag
2. Group by type (Added, Fixed, Changed, etc.)
3. Generate a changelog entry in Keep a Changelog format
4. Present the entry for review

**Ask the user to approve the changelog before writing.**

### Step 4: Bump Version in Project Files

Update version strings in the relevant files:

- **Node.js**: `package.json` (and `package-lock.json` via `npm version`)
- **Rust**: `Cargo.toml`
- **Python**: `pyproject.toml`, `setup.cfg`, or `__version__`
- **Go**: Version constants or tags only (no file to bump)
- **Other**: Search for version patterns in config files

```bash
# Node.js — use npm version (handles package.json + lock + tag)
npm version <major|minor|patch> --no-git-tag-version

# Or manual for other languages
# Update the version string in the detected file
```

**Present the file changes for review before committing.**

### Step 5: Commit and Tag

Create a release commit and tag:

```bash
# Ask the user to stage the release files first (staging is manual by design):
#   CHANGELOG.md + the version file (package.json / Cargo.toml / go.mod ...)

# Then commit
git commit -m "chore(release): vX.Y.Z"

# Create annotated tag
git tag -a vX.Y.Z -m "Release vX.Y.Z"
```

**Ask the user before executing the commit and tag.**

### Step 6: Push and Create GitHub Release

Ask the user before pushing or creating the release — both are public and hard to undo.

```bash
# Push the release commit and only this release's tag
git push && git push origin vX.Y.Z

# Create GitHub release using gh CLI.
# First save the approved changelog entry from Step 3 to a temp file:
#   /tmp/release-notes-vX.Y.Z.md
gh release create vX.Y.Z \
  --title "vX.Y.Z" \
  --notes-file /tmp/release-notes-vX.Y.Z.md
```

If `gh` CLI is not available, provide the release URL for manual creation:
```
https://github.com/OWNER/REPO/releases/new?tag=vX.Y.Z
```

## Quality Gates

The workflow's instructions stop for the user at each of these points; `git push` and `gh` are left out of `allowed-tools`, so the host also asks for permission before they run:
- Clean working tree before starting
- User confirms version number
- User approves changelog content
- User approves version bump file changes
- User approves commit and tag
- User approves push and GitHub release

## When to Use

Invoke `/ogxo-git:release` when you're ready to cut a new version. All code changes should be merged and tests passing.

**This workflow chains:**
1. Pre-flight verification
2. Version analysis (semver from commits)
3. Changelog generation (changelog-generator skill)
4. Version bump in project files
5. Git commit + annotated tag
6. Push + GitHub release (via `gh` CLI)
