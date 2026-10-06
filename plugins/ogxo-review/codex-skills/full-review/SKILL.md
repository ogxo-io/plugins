---
name: full-review
description: "Review local or PR changes with code and security passes, cross-correlate findings, and verify claims against source."
---

# Full Review

## Resolve the review scope

Run `git status --short` and `git branch --show-current` at runtime. Parse the scope from the user's request, not a command argument macro:

- `staged`: read `git diff --cached` and its `--name-only` list.
- `uncommitted`: read `git diff` and its `--name-only` list; list untracked files with `git ls-files --others --exclude-standard` and read them fully.
- No explicit scope: read `git diff` and `git diff --cached` separately, plus untracked files; preserve which change belongs to which layer.
- PR number/URL: read `gh pr view <PR> --json number,title,url,headRefName,baseRefName,headRefOid` and `gh pr diff <PR>`. Read files at the PR head revision rather than assuming the current checkout matches it.
- Branch/base: verify both refs and read `git diff <base>...<branch>` and its file list. Resolve the default base from `git symbolic-ref --quiet --short refs/remotes/origin/HEAD` if no base is supplied; ask if no verified default is available.

Inspect actual diff content and file lists. If the scope has neither changes nor selected new files, stop and report an empty scope with its exact base/branch/path; do not return a clean review verdict. Do not stage changes to combine scopes. Keep command errors distinct from empty output.
## Workers and procedures

Read the native specialist skill or its corresponding `../../agents/<name>.md` relative to this skill directory. Agent markdown supplies a workflow, not host configuration: ignore Claude model/tool metadata and resolve plugin-root references against `../..`. Use available worker tools with plain prompts that include repository, exact scope, diff commands, read-only instruction, and output fields. Respect concurrency limits and queue work as needed. If worker tools are unavailable, perform separate sequential passes and disclose the lack of independent verification. Optional external reviewers run only when their actual CLI/tool is available; do not invent a Codex MCP or Claude Agent API.

1. Read `../../agents/code-review-agent.md` and `../../agents/security-auditor.md`. Run their procedures as separate passes or independent workers. Both receive the same resolved diff and file revision; report only evidence-backed findings with path, line, severity, confidence, mechanism, and proposed remedy.
2. If `coderabbit` is installed, check its actual CLI help before running a read-only noninteractive review for this scope; collect its full output/errors. Use any genuinely exposed external review tool only within its documented interface. The current Codex session is the orchestrator, not automatically an additional independent reviewer. Report which reviewers ran and which were unavailable.
3. Normalize findings, merge duplicate mechanisms (retaining reporters), and distinguish corroboration from independent evidence. Read `../../agents/finding-verifier.md` and verify each claim against code, callers, guards, and tests. Give the verifier claims without reviewer reasoning; batch by file and use an independent worker when available.
4. Drop refuted claims, label uncertain claims, and retain confirmed findings with defensible severity. Return a unified table plus detailed evidence and checks/limitations, including failed dependency scans. Do not convert skipped checks into approval.
5. Present remediation options. Keep the review read-only; apply selected fixes only after the user requests them, then run appropriate tests and re-review the changed scope. No public comments or reactions are part of this workflow.
