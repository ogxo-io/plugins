---
name: changelog-generator
description: Generate CHANGELOG.md from Conventional Commits with semantic grouping and Keep a Changelog format. Use when the user wants to generate, write, or update a CHANGELOG.md, see what changed since the last tag, or prepare the changelog portion of a release.
allowed-tools: Bash(git describe:*), Bash(git tag:*), Bash(git log:*), Bash(git rev-list:*), Bash(git remote:*), Read, Glob, Grep
context: fork
background: false
model: sonnet
effort: low
---

# Changelog Generator

## Rules

Build every entry from the actual git log for the chosen range (Steps 1–2), not from memory or the conversation — the changelog is a record of what the commits contain.

Draft only: do not write or edit any file. This skill runs as a subagent so the commit log stays out of the main conversation; it returns the entry, and the session that invoked it shows the entry to the user and writes CHANGELOG.md only after they confirm (Step 6). Run inline, follow the same split: draft, present, confirm, then write.

For curated GitHub release notes, use the release-notes skill instead.

## Workflow Decision Tree

```
Is the user asking to:
├─ Generate changelog for a NEW release?
│  └─ Detect last tag → parse commits since tag → draft the entry to prepend to CHANGELOG.md
│
├─ Generate FULL changelog from scratch?
│  └─ List all tags → draft an entry per tag → draft the complete CHANGELOG.md
│
├─ Show what changed since last release?
│  └─ Detect last tag → parse commits → return a summary (no file to write)
│
├─ Generate changelog between TWO versions?
│  └─ Parse commits between the two tags → generate entry
│
└─ Update existing CHANGELOG.md with new version?
   └─ Read existing file → draft the new entry to prepend below its header
```

**Default path:** Generate changelog for the next release (last tag → HEAD).

## Step 1: Determine Version Range

Establish the commit range before parsing. Run each git command as its own Bash call from the repository root, with no `cd`, pipe, or `$(...)`: this skill's `allowed-tools` lists plain `git` calls, and a compound command does not match them. Put the tag you found into the next command yourself; shell variables do not persist between calls.

```bash
# The most recent tag
git describe --tags --abbrev=0

# Recent tags, newest first (the first ten lines are enough)
git tag --sort=-creatordate

# Commits since that tag (put the tag in place of <tag>)
git rev-list <tag>..HEAD --count
```

**Caution:** with no tags, `git describe` fails with "No names found". That means fall back to the full history and treat everything as the first release — it does not mean "no changes".

## Step 2: Parse Commits

```bash
# Subject AND body for every commit since the tag (with no tag, use HEAD instead of <tag>..HEAD).
# The body carries BREAKING CHANGE details and migration notes — %s alone misses them.
# %x1e emits a record separator so multi-line bodies stay parseable.
git log <tag>..HEAD --pretty=format:"%h%x09%s%x09%b%x1e" --no-merges

# Variant with author (for PR credit lines)
git log <tag>..HEAD --pretty=format:"%h %s (%an)" --no-merges

# For full changelog (all tags)
git log --pretty=format:"%h %s" --no-merges --decorate
```

**Parse each commit line into:**
- **Type**: feat, fix, refactor, perf, docs, test, chore, ci, build
- **Scope**: Optional component in parentheses
- **Description**: The commit message after type/scope
- **Breaking**: Commits with `BREAKING CHANGE:` in body or `!` after type
- **Hash**: Short commit hash for linking

Merge commits are already excluded by `--no-merges`. Group commits that don't follow Conventional Commits under an "Other Changes" section.

## Step 3: Detect GitHub Remote

Detect GitHub repository for PR/issue linking:

```bash
git remote get-url origin
```

Take `owner/repo` from a GitHub URL yourself: drop everything up to `github.com/` or `github.com:`, and a trailing `.git`. A failure or a non-GitHub URL means no links.

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

The current version is the last tag from Step 1 without a leading `v`, or the `version` field of `package.json` (read it with Read).

**Return the suggested version with the reason for it; the user confirms it before anything is written.**

## Step 6: Return the Entry

Read the existing CHANGELOG.md, if there is one, only to match its style and to check that this version is not already listed. Do not write it. End the reply with:

1. The range used (for example `v1.2.0..HEAD`) and the number of commits.
2. The suggested version and why (Step 5).
3. The entry in one fenced `markdown` block, ready to paste. For a file created from scratch, the block is the whole file, starting with this header:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).
```

4. This line for the invoking session: "Show this entry and version to the user. Only after they confirm, insert the entry below the `# Changelog` header of CHANGELOG.md (or create the file from the block), keeping every existing entry."

## Quick Reference Checklist

When generating a changelog, complete these steps in order:

- [ ] **Step 1:** Determine version range (last tag → HEAD)
- [ ] **Step 2:** Parse git log for conventional commits
- [ ] **Step 3:** Detect GitHub remote for linking
- [ ] **Step 4:** Group by type with Keep a Changelog sections
- [ ] **Step 5:** Suggest version number (the user confirms it)
- [ ] **Step 6:** Return the entry; the invoking session writes CHANGELOG.md after the user confirms
