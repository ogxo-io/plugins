---
name: changelog-generator
description: Generate CHANGELOG.md from Conventional Commits with semantic grouping and Keep a Changelog format. Use when the user wants to generate, write, or update a CHANGELOG.md, see what changed since the last tag, or prepare the changelog portion of a release.
allowed-tools: Bash(git describe:*), Bash(git tag:*), Bash(git log:*), Bash(git rev-list:*), Bash(git remote:*), Read, Write, Glob, Grep
effort: low
---

# Changelog Generator

## Rules

Build every entry from the actual git log for the chosen range (Steps 1–2), not from memory or the conversation — the changelog is a record of what the commits contain.

For curated GitHub release notes, use the release-notes skill instead.

## Workflow Decision Tree

```
Is the user asking to:
├─ Generate changelog for a NEW release?
│  └─ Detect last tag → parse commits since tag → generate entry → prepend to CHANGELOG.md
│
├─ Generate FULL changelog from scratch?
│  └─ List all tags → generate entry per tag → write complete CHANGELOG.md
│
├─ Show what changed since last release?
│  └─ Detect last tag → parse commits → display summary (don't write file)
│
├─ Generate changelog between TWO versions?
│  └─ Parse commits between the two tags → generate entry
│
└─ Update existing CHANGELOG.md with new version?
   └─ Read existing file → generate new entry → prepend below header
```

**Default path:** Generate changelog for the next release (last tag → HEAD).

## Step 1: Determine Version Range

Establish the commit range before parsing.

```bash
# Get the most recent tag
git describe --tags --abbrev=0 2>/dev/null

# List recent tags with dates
git tag --sort=-creatordate | head -10

# Get commit count since last tag
git rev-list $(git describe --tags --abbrev=0 2>/dev/null)..HEAD --count 2>/dev/null
```

**Caution:** when no tags exist, the range commands above succeed with empty output (`0` commits) instead of erroring. Empty output with no tag means fall back to the full history (`git log --oneline`) and treat everything as the first release — it does not mean "no changes".

## Step 2: Parse Commits

```bash
# One call: resolve the range, then list commits with subject AND body.
# The body carries BREAKING CHANGE details and migration notes — %s alone misses them.
# %x1e emits a record separator so multi-line bodies stay parseable.
TAG=$(git describe --tags --abbrev=0 2>/dev/null); RANGE=${TAG:+$TAG..}HEAD
git log $RANGE --pretty=format:"%h%x09%s%x09%b%x1e" --no-merges

# Variant with author (for PR credit lines)
git log $RANGE --pretty=format:"%h %s (%an)" --no-merges

# For full changelog (all tags)
git log --pretty=format:"%h %s" --no-merges --decorate
```

Run the `TAG=`/`RANGE=` line in the **same Bash call** as the `git log` that uses it — shell variables do not persist between calls.

**Parse each commit line into:**
- **Type**: feat, fix, refactor, perf, docs, test, chore, ci, build
- **Scope**: Optional component in parentheses
- **Description**: The commit message after type/scope
- **Breaking**: Commits with `BREAKING CHANGE:` in body or `!` after type
- **Hash**: Short commit hash for linking

**Skip these commits:**
- Merge commits (already included via `--no-merges`)
- Commits that don't follow Conventional Commits (group under "Other Changes" if present)

## Step 3: Detect GitHub Remote

Detect GitHub repository for PR/issue linking:

```bash
# Get GitHub remote URL
git remote get-url origin 2>/dev/null | sed -E 's/.*github\.com[:/](.+)(\.git)?$/\1/' | sed 's/\.git$//'
```

If a GitHub remote is detected, generate links:
- Commit hashes: `[abc1234](https://github.com/owner/repo/commit/abc1234)`
- PR references: `#123` → `[#123](https://github.com/owner/repo/pull/123)`
- Issue references: `Closes #456` → linked automatically

## Step 4: Group and Format

Use [Keep a Changelog](https://keepachangelog.com/) format with Conventional Commits mapping:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- feat commits listed here

### Fixed
- fix commits listed here

### Changed
- refactor, perf commits listed here

### Removed
- Commits that remove features/code

### Security
- Security-related fix commits

### Breaking Changes
- BREAKING CHANGE commits listed here with migration notes
```

**Type → Section mapping:**
| Commit Type | Changelog Section |
|-------------|------------------|
| `feat` | Added |
| `fix` | Fixed |
| `refactor` | Changed |
| `perf` | Changed |
| `docs` | (skip unless user requests) |
| `test` | (skip unless user requests) |
| `chore` | (skip unless user requests) |
| `ci`, `build` | (skip unless user requests) |
| `BREAKING CHANGE` | Breaking Changes (always include) |

**Formatting rules:**
- Each entry starts with a dash and space: `- `
- Include scope in bold if present: `- **auth:** add OAuth2 support`
- Append commit hash in parentheses: `([abc1234](link))`
- List breaking changes with migration instructions taken from the commit body (Step 2 captures `%b` for exactly this)
- Empty sections are omitted
- `Breaking Changes` is an intentional extension to the six canonical Keep a Changelog sections — include it whenever breaking commits exist

## Step 5: Determine Version Number

If the user hasn't specified a version, suggest one based on commits:

- **MAJOR** (X.0.0): Any `BREAKING CHANGE` commit exists
- **MINOR** (0.X.0): Any `feat` commit exists (no breaking changes)
- **PATCH** (0.0.X): Only `fix`, `refactor`, `perf`, `docs`, etc.

```bash
# Current version from last tag
current=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')

# Or from package.json
grep '"version"' package.json | head -1 | sed 's/.*"\([0-9.]*\)".*/\1/'
```

**Always present the suggested version and ask the user to confirm before writing.**

## Step 6: Write or Update CHANGELOG.md

**When updating an existing CHANGELOG.md:**
1. Read the existing file
2. Insert the new version entry after the `# Changelog` header
3. Preserve all existing entries below

**When creating from scratch:**
```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [X.Y.Z] - YYYY-MM-DD

### Added
- ...
```

**Present the changelog entry to the user before writing the file.**

## Common Mistakes to Avoid

### Mistake 1: Writing Changelog from Memory

**Wrong:**
```
User: "Generate changelog"
Assistant: *writes changelog based on what it remembers from the conversation*
```

**Correct:**
```
User: "Generate changelog"
Assistant: *runs git log to parse actual commits, then formats*
```

### Mistake 2: Including Noise Commits

**Wrong:** Including every `chore:`, `ci:`, and `test:` commit in the changelog.

**Correct:** Only include `feat`, `fix`, `refactor`, `perf`, and breaking changes by default. Include others only when requested.

### Mistake 3: Wrong Version Bump

**Wrong:** Suggesting a PATCH version when there are new features.

**Correct:** Follow semver — any `feat` = MINOR bump, any `BREAKING CHANGE` = MAJOR bump.

## Quick Reference Checklist

When generating a changelog, complete these steps in order:

- [ ] **Step 1:** Determine version range (last tag → HEAD)
- [ ] **Step 2:** Parse git log for conventional commits
- [ ] **Step 3:** Detect GitHub remote for linking
- [ ] **Step 4:** Group by type with Keep a Changelog sections
- [ ] **Step 5:** Suggest version number (confirm with user)
- [ ] **Step 6:** Write/update CHANGELOG.md (present entry first)
