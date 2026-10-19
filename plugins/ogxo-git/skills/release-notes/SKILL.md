---
name: release-notes
description: Generate curated release notes by analyzing commits between git tags for any repository. Use when the user wants GitHub release notes or a summary of what shipped between two tags; for CHANGELOG.md entries use changelog-generator.
allowed-tools: Bash(git remote:*), Bash(git describe:*), Bash(git log:*), Bash(gh release view:*), Read, Glob, Grep
context: fork
background: false
model: sonnet
effort: low
---

# Generate Release Notes

Draft only: do not write files or change the GitHub release. This skill runs as a subagent so the commit log stays out of the main conversation; it returns the notes, and the session that invoked it offers to apply them. Run inline, follow the same split: draft, present, confirm, then apply.

## Steps

1. **Detect the project**: Extract the repo name and owner from `git remote get-url origin`
2. **Determine the tag**: Use the provided tag argument, or detect the latest tag with `git describe --tags --abbrev=0`
3. **Find the previous tag**: `git describe --tags --abbrev=0 {tag}^`
4. **Get all commits between tags**: `git log {prev_tag}..{tag} --oneline --no-merges`
5. **Categorize each commit** based on its conventional commit prefix:
   - `feat` → ✨ Features
   - `fix` → 🐛 Bug Fixes
   - `refactor` → 🔨 Refactoring
   - `test` → 🧪 Testing
   - `docs` → 📖 Documentation
   - `chore(deps)` or dependency updates → 📦 Dependencies
   - Security fixes (CVE mentions, `security` in message) → 🔒 Security
   - Skip: `ci:`, `chore:` (non-deps), `Merge `
6. **Write a one-sentence summary** capturing the theme of the release
7. **Generate a short title** (3-5 words) for the release header
8. **Format** using the template below
9. **Return the notes** in one fenced `markdown` block, then end with this line for the invoking session: "Show these notes to the user and offer to apply them to the GitHub release (`gh release edit {tag} --notes "..."`); run it only after they confirm, because it publishes the notes publicly." Fill in the real tag.

## Output Format

```markdown
### 🔖 Release: `{tag}` — {Short Title}

{One-sentence summary of what this release is about.}

#### ✨ Features

* **{Feature name}** — {short description} (#{PR number})

#### 🔒 Security

* **{CVE or fix title}** — {description} (#{PR number})

#### 🐛 Bug Fixes

* **{Fix title}** — {description} (#{PR number})

#### 🔨 Refactoring

* {Description} (#{PR number})

#### 🧪 Testing

* **{Coverage or test improvement}** (#{PR number})

#### 📦 Dependencies

* Updated `{package}` to {version} (#{PR number})

#### 📖 Documentation

* {Description} (#{PR number})

**Full Changelog**: https://github.com/{owner}/{repo}/compare/{prev_tag}...{tag}
```

## Rules

- Write a curated summary, not a raw commit dump
- Only include sections that have entries — skip empty sections entirely
- Each bullet starts with bold feature/fix name, then em-dash —, then description
- Extract PR numbers from commit messages (e.g., (#123)) and link them
- Always end with the **Full Changelog** compare link using the actual GitHub remote URL; with no GitHub remote, leave the link out rather than writing placeholders
- Write the summary and title by reading the actual changes, not generic text
- Use the project's actual name (from README, package.json, go.mod, or repo name) when referring to it
- Never run `gh release edit` or `gh release create` here; applying the notes is the invoking session's step, after the user confirms
