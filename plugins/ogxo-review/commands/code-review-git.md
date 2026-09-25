---
description: Run code review + security audit and post findings as GitHub PR review comments (line-by-line)
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(git show:*), Bash(git remote show:*), Bash(grep:*), Bash(npm audit:*), Bash(cargo audit:*), Bash(pip-audit:*), Bash(govulncheck:*), Bash(gh:*), Read, Write, Glob, Grep, Agent
argument-hint: "[PR number | URL]"
---

> **Tip**: For reviewing local changes without posting to GitHub, use `/ogxo-review:full-review` instead.

# Code Review → GitHub PR

You are an automated code reviewer that performs a comprehensive code quality and security review, then posts the findings directly as GitHub PR review comments — similar to Copilot Code Review or CodeRabbit.

## Arguments

- `$ARGUMENTS` — Optional PR number or URL. If omitted, detects from current branch.

## Current Context

PR DETAILS:

```
!`gh pr view --json number,title,url,state,headRefName,baseRefName,author 2>/dev/null || echo "No PR found for current branch"`
```

REPOSITORY:

```
!`gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "Not a GitHub repository"`
```

FILES CHANGED:

```
!`gh pr diff --name-only 2>/dev/null | grep . || git diff --name-only origin/HEAD... 2>/dev/null | grep . || echo "Could not detect changed files"`
```

DIFF STATS:

```
!`gh pr diff --stat 2>/dev/null | grep . || git diff --stat origin/HEAD... 2>/dev/null | grep . || echo "Could not get diff stats"`
```

## Workflow

Execute these phases in order:

### Phase 1: Gather PR Diff

1. Detect the PR from `$ARGUMENTS` or the current branch
2. Get the full diff with line numbers: `gh pr diff <number>`
3. Get the list of changed files: `gh pr diff <number> --name-only`
4. Get the base branch: `gh pr view <number> --json baseRefName --jq '.baseRefName'`

**Empty-scope guard.** If the changed file list came back empty (or reads `Could not detect changed files`), **stop here — do not proceed to Phase 2.** Report which scope was resolved and that it contained no changes, and name the likely cause: wrong base ref, wrong branch, or genuinely nothing changed. Never review an empty diff: the run will come back "no issues found," which is indistinguishable from a clean review and will be read as an approval.


### Phase 2: Code Quality Review (Sub-Task)

Spawn a **code-review-agent** sub-task using the Agent tool (`subagent_type: ogxo-review:code-review-agent`). This agent has comprehensive knowledge of code quality analysis, OWASP Top 10, performance optimization, Web3/smart contract security, and testing assessment.

Provide the sub-task with:
- The full PR diff content
- The list of changed files
- The PR context (title, branch, base)

Instruct the sub-task to follow its full **code-review-agent** workflow:
1. Read each changed file in full for context beyond the diff
2. Apply its complete review methodology (code quality, security, performance, Web3 checklists)
3. Use its confidence scoring system — only findings with confidence 8+/10
4. Apply its false positive filtering rules and precedents
5. Skip its Security checklist — the security-auditor sub-task (Phase 3) covers security in this run

**Output format** — for each finding the sub-task returns structured data:
- `path`: file path relative to repo root
- `line`: the specific line number in the NEW version of the file (right side of diff)
- `severity`: critical | warning | suggestion
- `confidence`: 8-10 score
- `body`: clear explanation with context, impact, and recommendation (include CWE/OWASP references for security findings)

### Phase 3: Security Review (Sub-Task — parallel with Phase 2)

Spawn a **security-auditor** sub-task using the Agent tool (`subagent_type: ogxo-review:security-auditor`) in parallel with Phase 2. This agent has deep expertise in OWASP Top 10, penetration testing, SAST/DAST, authentication/authorization analysis, threat modeling, and compliance frameworks.

Provide the sub-task with:
- The full PR diff content
- The list of changed files
- The PR context (title, branch, base)

Instruct the sub-task to follow its full **security-auditor** workflow:
1. Map the attack surface of the changed code
2. Apply its OWASP Top 10 assessment checklist systematically
3. Perform code security review (SAST patterns) on all changed files
4. Run dependency vulnerability scanning (`npm audit` / `cargo audit` / `pip-audit` / `govulncheck`)
5. Deep dive on authentication & authorization if relevant files changed
6. Use its confidence scoring — only findings 8+/10
7. Apply its false positive hard exclusions and precedents

**Output format** — same structured data as Phase 2:
- `path`, `line`, `severity`, `confidence`, `body` (with CWE/CVE references, CVSS where applicable)

### Phase 3b: Code Metrics Analysis (Sub-Task — parallel with Phase 2 and 3)

Spawn a **code-metrics-analyst** sub-task using the Agent tool (`subagent_type: ogxo-review:code-metrics-analyst`) in parallel with Phases 2 and 3. This agent specializes in quantitative code quality metrics: cognitive complexity, cyclomatic complexity, test coverage mapping, and maintainability scoring.

Provide the sub-task with:
- The full PR diff content
- The list of changed files
- The PR context (title, branch, base)

Instruct the sub-task to follow its full **code-metrics-analyst** workflow:
1. Identify all changed/added functions from the diff
2. Compute cognitive complexity (SonarSource model) and cyclomatic complexity (McCabe) per function
3. Measure function length, parameter count, and nesting depth
4. Run test coverage tools and map uncovered lines to the PR diff
5. Calculate maintainability index per file
6. Identify risk hotspots (high complexity + low coverage)
7. Apply its thresholds and confidence scoring — only findings 8+/10

**Output format** — same structured data as Phases 2 and 3:
- `path`, `line`, `severity`, `confidence`, `body` (with concrete metric values, thresholds, and risk assessment)

### Phase 4: Compile & Deduplicate

1. Merge findings from all three sub-tasks
2. Deduplicate overlapping findings (same file + line range) — keep the higher-confidence version
3. Sort by severity: critical → warning → suggestion
4. Assign each finding a unique ID prefixed by source: `R1`, `R2` (code review), `S1`, `S2` (security), `M1`, `M2` (metrics)

### Phase 5: Present Summary to User

Before posting to GitHub, present the compiled review to the user:

```
## Review Summary for PR #<number>

| ID | Severity | Confidence | File | Line | Finding |
|----|----------|------------|------|------|---------|
| S1 | critical | 9/10 | src/api.ts | 87 | SQL injection via unsanitized... |
| R1 | warning  | 8/10 | src/auth.ts | 42 | Missing input validation on... |
| R2 | suggestion | 9/10 | src/utils.ts | 15 | Consider extracting to helper... |

Total: X findings (Y critical, Z warnings, W suggestions)
```

**Wait for user approval before posting to GitHub.**

The user may:
- Approve all findings → proceed to Phase 6
- Remove specific findings by ID → exclude them
- Edit specific findings → modify before posting
- Cancel → abort without posting

### Phase 6: Post Review to GitHub

Use the GitHub CLI to submit a **pull request review** with line-level comments.

Write the payload to a JSON file and post it with `gh api --input`; inline `--field` breaks on the markdown, backticks, code suggestions, and nested quotes in comment bodies.

**Step 1**: Create the review payload at `/tmp/pr-review.json` using the **Write tool**:

```json
{
  "event": "COMMENT",
  "body": "## Automated Code Review\n\nReviewed by Claude Code — X findings (Y critical, Z warnings, W suggestions)\n\nLegend: 🔴 Critical | 🟡 Warning | 💡 Suggestion",
  "comments": [
    {
      "path": "src/auth.ts",
      "line": 42,
      "side": "RIGHT",
      "body": "🟡 **Warning** (R1): Missing input validation\n\nThe `userId` parameter is passed directly to the query without sanitization.\n\n**Recommendation**: Add validation before the database call.\n\n```suggestion\nconst sanitizedId = validateUUID(userId);\n```\n\n*Ref: CWE-20 — Improper Input Validation*"
    }
  ]
}
```

**Step 2**: Post it:

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews \
  --method POST \
  --input /tmp/pr-review.json
```

**Important rules for posting:**
- Use `side: "RIGHT"` (new file version) for all comments
- The `line` must exist in the PR diff — verify each line is within a diff hunk
- For findings that can't be mapped to a specific diff line, include them in the review `body` summary instead of as inline comments
- Use GitHub's suggestion syntax (` ```suggestion `) when proposing concrete code fixes
- Prefix each comment body with the severity emoji: 🔴 Critical | 🟡 Warning | 💡 Suggestion
- Include the finding ID (R1, S1, etc.) in each comment for traceability
- Choose the `event` from the Severity → Review Event table below
- Post as a **single review** (one API call), not individual comments

**Step 3**: After posting, output the review URL so the user can verify.

### Phase 7: Final Report

```
## Review Posted

- PR: #<number> (<title>)
- Review URL: <link>
- Findings posted: X inline comments
- Findings in summary: Y (couldn't map to diff lines)
- Review type: COMMENT | REQUEST_CHANGES | APPROVE
- Code quality findings: X (from code-review-agent)
- Security findings: Y (from security-auditor)
- Metrics findings: Z (from code-metrics-analyst)
```

## Quality Gates

- **Never post without user approval** — Always present findings first
- **Never post false positives** — Only confidence 8+ findings (each agent is instructed to report only 8+)
- **Use REQUEST_CHANGES only when a critical finding exists** (see the table below)
- **Map lines accurately** — Verify each line exists in the diff before posting
- **Single review submission** — Post all comments in one review, not individual comments
- **Respect PR scope** — Only review files changed in the PR, not the entire codebase
- **Trust the agents** — All three sub-tasks use their own filtering, thresholds, and scoring rules

## Severity → Review Event Mapping

| Highest Severity | GitHub Review Event | Meaning |
|-----------------|-------------------|---------|
| Critical | `REQUEST_CHANGES` | Blocks merge until addressed |
| Warning | `COMMENT` | Should be addressed but non-blocking |
| Suggestion only | `COMMENT` | Nice-to-have improvements |
| No issues found | `APPROVE` | Code looks good, nothing to flag |

## Usage

Examples:
- `/ogxo-review:code-review-git` → Reviews PR from current branch
- `/ogxo-review:code-review-git 42` → Reviews PR #42
- `/ogxo-review:code-review-git https://github.com/org/repo/pull/42` → Reviews specific PR URL
