---
name: security-check
description: "Review branch changes for concrete security defects and scan relevant dependencies, with claim verification."
---

# Security Check

## Resolve the review scope

Run `git status --short` and `git branch --show-current` at runtime. Parse the scope from the user's request, not a command argument macro:

- `staged`: read `git diff --cached` and its `--name-only` list.
- `uncommitted`: read `git diff` and its `--name-only` list; list untracked files with `git ls-files --others --exclude-standard` and read them fully.
- No explicit scope: review this branch against the verified remote default branch, as the Claude Code command does: read `git diff --merge-base <default>` (committed branch changes plus tracked local changes) and its `--name-only` list, and list untracked files with `git ls-files --others --exclude-standard` and read them fully.
- PR number/URL: read `gh pr view <PR> --json number,title,url,headRefName,baseRefName,headRefOid` and `gh pr diff <PR>`. Read files at the PR head revision rather than assuming the current checkout matches it.
- Branch/base: verify both refs and read `git diff <base>...<branch>` and its file list. Resolve the default base from `git symbolic-ref --quiet --short refs/remotes/origin/HEAD` if no base is supplied; ask if no verified default is available.

Inspect actual diff content and file lists. If the scope has neither changes nor selected new files, stop and report an empty scope with its exact base/branch/path; do not return a clean review verdict. Do not stage changes to combine scopes. Keep command errors distinct from empty output.

## Workers and procedures

Read the native specialist skill or its corresponding `../../agents/<name>.md` relative to this skill directory. Agent markdown supplies a workflow, not host configuration: ignore Claude model/tool metadata and resolve plugin-root references against `../..`. Use available worker tools with plain prompts that include repository, exact scope, diff commands, read-only instruction, and output fields. Respect concurrency limits and queue work as needed. If worker tools are unavailable, perform separate sequential passes and disclose the lack of independent verification. Optional external reviewers run only when their actual CLI/tool is available; do not invent a Codex MCP or Claude Agent API.

1. Read `../../agents/security-auditor.md` and its referenced security playbook. Identify the repository's threat model and existing controls, then trace modified data flows from untrusted inputs to sensitive operations. Keep this a defensive source review; report concrete security impact supported by code rather than broad hardening suggestions.
2. Read `../../agents/finding-verifier.md`. Independently verify each candidate with its callers, validation, authorization, framework defaults, and tests. Use worker tools when available; otherwise perform a separate skeptical pass and disclose that limitation. Retain only high-confidence findings (8+/10); state residual uncertainty.
3. Detect the package manager and run the applicable installed scanner (`npm audit --json`, `cargo audit`, `pip-audit`, or `govulncheck ./...`) when the host permits it. Keep stderr and report absent tools, network failures, and unsuccessful scans. Separate pre-existing dependency findings from vulnerabilities introduced by this change.
4. Return scope/base/revision, findings with file:line, severity, confidence, data-flow evidence, remediation, dependency results, and scan limitations. Leave files unchanged and do not publish findings.
