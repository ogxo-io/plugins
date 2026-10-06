---
name: ship-feature
description: "Run quality gates, commit staged work, and prepare or publish a pull request using the host tools."
---

# Ship Feature

1. Read repository instructions; run `git status --short`, `git branch --show-current`, `git diff`, and `git diff --cached` separately at runtime. Parse the user's optional base branch and `--no-gates` flag from their request. Resolve the default base using `git symbolic-ref --quiet --short refs/remotes/origin/HEAD`, verify it exists, or ask for a base.
2. Unless the user requested `--no-gates`, run a source-based security review, the project's non-watch test suite, and its production build where one exists. Use an installed security-auditor skill as a procedure, or perform that review directly. Use available workers with plain prompts if delegation is supported; otherwise run sequentially. Report missing checks and stop on failed gates. `--no-gates` is for gates already completed; state which evidence is being reused.
3. Inspect the actual staged diff. If nothing is staged but there are local changes to ship, show them and ask the user to stage. Do not stage. If nothing is staged and commits already exist ahead of the base, proceed with those commits. An empty staged and branch diff is an empty-scope result; stop.
4. If still on the base branch, create a branch based on the change and issue key with `git switch -c`. Read `../../skills/git-commit-generator/SKILL.md` and prepare a staged-only commit. Commit when authorized with signing/hooks intact and no unrequested attribution.
5. Read `../../skills/pr-generator/SKILL.md`. Prepare the PR title/body from the non-empty branch diff against the resolved base. Include checks actually run, the repo template, and an issue prefix for a KLC branch; omit attribution. Save the exact multiline body to a temporary file.
6. Show branch, commits (`git log <base>..HEAD`), title, and body. Obtain approval for push/PR publication unless already authorized in the session. On approval run `git push -u origin <branch>` and `gh pr create --base <base> --title <title> --body-file <file>`, then report the returned URL. Do not force-push. If GitHub tooling/authentication is missing, return the concrete title/body and explain what remains.
