---
description: Ship staged work as a pull request - quality gates, then branch, commit, push, and open the PR, with one confirmation before anything is pushed
argument-hint: "[--no-gates] [base-branch]"
allowed-tools: Bash(git status:*), Bash(git branch:*), Bash(git diff:*), Bash(git log:*), Bash(git switch:*), Bash(git commit:*), Bash(git push:*), Bash(git rev-parse:*), Bash(git symbolic-ref:*), Bash(gh pr:*), Bash(gh auth status:*), Bash(npm:*), Bash(pnpm:*), Bash(yarn:*), Bash(cargo:*), Bash(go:*), Bash(uv:*), Bash(pytest:*), Bash(python3:*), Read, Glob, Grep, Agent, Skill
---

# Ship Feature

You are a senior engineer responsible for quality-gated feature delivery.

## Current Context

GIT STATUS:

```
!`git status 2>/dev/null`
```

CURRENT BRANCH:

```
!`git branch --show-current 2>/dev/null`
```

STAGED:

```
!`git diff --cached --stat 2>/dev/null`
```

Arguments: `$ARGUMENTS`. `--no-gates` skips steps 1-3, for work whose tests and review already ran; a remaining argument is the base branch (default: the repository's default branch, from `git symbolic-ref refs/remotes/origin/HEAD`).

## Workflow Execution

Execute in this order. Stop immediately if any quality gate fails, and say which one.

1. **Security Review** (skipped with `--no-gates`): Invoke the `ogxo-review:security-auditor` agent (from the ogxo-review plugin) to scan for OWASP Top 10 vulnerabilities; if that agent isn't installed, tell the user and ask whether to continue without the security gate
2. **Run Tests** (skipped with `--no-gates`): Run the project's own test command, as its `CLAUDE.md`, Makefile, or package scripts define it (for example `pnpm test`, `cargo test`, `uv run pytest`, `go test ./...`), in non-watch mode, to ensure all tests pass
3. **Build Verification** (skipped with `--no-gates`): Run the production build to catch compilation or build errors
4. **Review & Stage**: Present the changed-file list. Staging is manual by design: if nothing is staged, ask the user to stage what should ship and stop until they have (suggest excluding planning artifacts like `plan.md` or task notes). Never run `git add` yourself. If there is nothing to commit and the branch already has commits ahead of the base, skip to step 7.
5. **Branch**: If the current branch is the base branch, create a branch with `git switch -c <name>` before committing. Name it from the change: `<type>/<short-kebab-summary>` (for example `feat/thryx-connect`), with the issue key first when the request or the work names one (`KLC-123-oauth-login`, `THRY-45-fix-export`). Staged changes carry over to the new branch. On any other branch, stay on it.
6. **Commit**: Invoke the **git-commit-generator** skill (`ogxo-git:git-commit-generator`) for the conventional commit message, then run `git commit` with it. Follow the user's commit rules: no attribution trailers unless they ask, and never `--no-verify` or `--no-gpg-sign`; a GPG prompt is expected. If a hook fails, report it and stop.
7. **Prepare the PR**: Invoke the **pr-generator** skill (`ogxo-git:pr-generator`) against the base branch for the title and description (test plan, issue-key linking, the repository's PR template). No attribution lines in the description unless the user asks.
8. **Confirm once**: Show the branch, the commit(s) that will be pushed (`git log --oneline <base>..HEAD`), and the PR title and description, and ask whether to push and open the PR. This is the only confirmation; pushing and opening a PR are visible to the team, so never skip it.
9. **Push and open**: On yes, `git push -u origin <branch>` (never `--force`), then `gh pr create --base <base> --title ... --body ...` (pr-generator's Option 3), and return the PR URL. If `gh auth status` fails, push anyway only if the user confirmed it, then print the title and body for them to paste. On no, leave the commit local and say how to resume (`/ogxo-git:ship-feature --no-gates`).

## Quality Gates

Unless `--no-gates` is given, this workflow runs these checks before the PR (the security step is an agent review, not a guarantee):

- A security review for OWASP Top 10 and common vulnerability patterns
- All unit and integration tests passing
- Production build succeeds without errors

Every run keeps conventional commit format, a PR description with a test plan and issue references, and one confirmation before the push.

## When to Use

Invoke this workflow when a feature is ready to ship and its changes are staged. Use `--no-gates` when tests and review already ran in the session and you only want the branch, commit, push, and PR.
