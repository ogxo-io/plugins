---
description: Multi-agent code review with cross-correlation and false positive detection
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(git show:*), Bash(git ls-files:*), Bash(git remote show:*), Bash(grep:*), Bash(which coderabbit:*), Bash(coderabbit:*), Bash(npm audit:*), Bash(cargo audit:*), Bash(pip-audit:*), Bash(govulncheck:*), Bash(gh pr view:*), Bash(gh pr diff:*), Read, Edit, Glob, Grep, Agent, mcp__codex__codex
argument-hint: "[PR number | URL | branch | staged | uncommitted]"
---

# Full Review

You are a multi-agent review orchestrator. You dispatch up to 4 independent review agents in parallel, normalize and correlate their findings, have `ogxo-review:finding-verifier` check every finding against the code, and present a unified cross-agent table with an option to fix.

## Arguments

- `$ARGUMENTS` — Optional PR number, URL, branch name, or keyword (`staged`, `uncommitted`). If omitted, reviews all current changes (unstaged + staged).

## Current Context

GIT STATUS:

```
!`git status 2>/dev/null`
```

BRANCH:

```
!`git branch --show-current 2>/dev/null`
```

PR (if any):

```
!`gh pr view --json number,title,url,state,headRefName,baseRefName 2>/dev/null || echo "No PR found for current branch"`
```

FILES CHANGED:

```
!`gh pr diff --name-only 2>/dev/null | grep . || git diff --name-only origin/HEAD... 2>/dev/null | grep . || git diff --name-only 2>/dev/null | grep . || echo "No changes detected"`
```

DIFF STATS:

```
!`gh pr diff --stat 2>/dev/null | grep . || git diff --stat origin/HEAD... 2>/dev/null | grep . || git diff --stat 2>/dev/null | grep . || echo "No diff stats"`
```

## Workflow

Execute these phases in order:

### Phase 1: Detect Context

Determine the review scope from `$ARGUMENTS`:

1. **`staged`** — review only staged changes: `git diff --staged` for the diff, `git diff --staged --name-only` for the file list
2. **`uncommitted`** — review only unstaged changes: `git diff` for the diff, `git diff --name-only` for the file list
3. **PR number** (e.g., `42`) or **URL** (e.g., `https://github.com/org/repo/pull/42`) — extract the number, use `gh pr diff <number>` for the full diff and `gh pr diff <number> --name-only` for the file list
4. **Branch name** (e.g., `feature/auth`) — resolve the default branch with `git remote show origin` (the `HEAD branch:` line), then use `git diff <default>...<branch>` for the full diff and `git diff <default>...<branch> --name-only` for the file list
5. **No arguments** — combine `git diff` (unstaged) and `git diff --staged` (staged) for the full diff; combine `git diff --name-only` and `git diff --staged --name-only` for the file list

For **`uncommitted`** and **no arguments**, also list new untracked files with `git ls-files --others --exclude-standard`. No diff shows them, so they are reviewed by reading them in full: add them to the file list, marked as new, and tell every reviewer to read them whole.

Gather and store for later phases:
- Full diff content (with line numbers)
- Changed file list
- Diff stats

**Empty-scope guard.** If the changed file list came back empty (or reads `No changes detected`), **stop here — do not proceed to Phase 2.** Report which scope was resolved and that it contained no changes, and name the likely cause: wrong base ref, wrong branch, a pathspec that matched nothing, or genuinely nothing changed. Never dispatch review agents against an empty diff: the run will come back "no issues found," which is indistinguishable from a clean review and will be read as an approval.

### Phase 2: Check Agent Availability

Before dispatching, detect which agents are available. Only a single cheap check is needed — the expensive agents (Codex, CodeRabbit review) get attempted directly in Phase 3 and handle their own failure.

1. **code-review-agent** — Always available (bundled in this plugin as `ogxo-review:code-review-agent`)
2. **CodeRabbit CLI** — Run `which coderabbit` — available if exit code is 0
3. **Codex MCP** — Available only if a Codex MCP tool (e.g. `mcp__codex__codex`) is present in this session; otherwise skip it. Do **not** probe it with a test call; the real invocation in Phase 3 will surface errors. A probe call doubles Codex cost since Codex is the slowest reviewer.
4. **Security auditor** — Always available (bundled in this plugin as `ogxo-review:security-auditor`)

Report to the user:

```
Agents available: N/4 — [list of available agents]. [Note any unavailable agents.]
```

If only 2 agents are available (the always-available ones), proceed normally — that is the minimum viable configuration.

### Phase 3: Parallel Agent Dispatch

Issue all of the following calls in one message so they run in parallel.

The main agent (this orchestrator) parses and normalizes all results directly in Phase 4 — do not wrap the simple single-call reviewers (CodeRabbit, Codex) in subagents. Subagents are only used for the two reviewers that require genuine multi-step analysis (code-review-agent, security-auditor).

Dispatch map:

| # | Reviewer | Invocation | Why |
|---|----------|------------|-----|
| 3a | code-review-agent | `Agent` subagent (`ogxo-review:code-review-agent`) | Multi-step analysis across 5 review dimensions |
| 3b | CodeRabbit CLI | Direct `Bash` call, in the background | Single CLI invocation, no reasoning needed; it can take minutes |
| 3c | Codex MCP | Direct `mcp__codex__codex` call | Single MCP call with the diff |
| 3d | security-auditor | `Agent` subagent (`ogxo-review:security-auditor`) | Multi-step SAST + dependency scan workflow |

All four calls go in the same assistant message.

#### 3a: code-review-agent (Agent subagent)

Spawn the `ogxo-review:code-review-agent` subagent for a comprehensive review of the diff.

Provide:
- The full diff content
- The list of changed files
- Branch/PR context (title, base branch)

Instruct the sub-task to run its full workflow, and, for this dispatch only, to include findings at every confidence (1-10) rather than only 8+, because Phase 6 verifies every finding and marks the wrong ones instead of dropping them.

**Required output format** — for each finding return:
- `path`: file path relative to repo root
- `line`: specific line number in the new version of the file
- `severity`: critical | warning | suggestion
- `confidence`: 1-10 score
- `body`: clear explanation with context, impact, and recommendation
- `verified`: `ran <command>` or `read`

#### 3b: CodeRabbit CLI — direct Bash call (if available)

Call `Bash` **directly** (no subagent wrapper), with `run_in_background`: a review often takes several minutes. Collect its output once the agents return, and allow it up to 10 minutes in all. **Always pass `--agent`**, which prints structured findings without the interactive mode (that mode hangs in a subprocess).

Commands by context (CodeRabbit CLI 0.8):
- **All changes (default)**: `coderabbit review --agent` (add `--include-untracked` when Phase 1 found untracked files)
- **Uncommitted only**: `coderabbit review --agent --uncommitted` (same note on `--include-untracked`)
- **Committed only**: `coderabbit review --agent --committed`
- **Specific base branch**: `coderabbit review --agent --base <base>`

If the CLI rejects `--agent` (`unknown option`), it is an older version: retry once with `--plain`, and `--type uncommitted` or `--type committed` in place of `--uncommitted` or `--committed`.

Capture the full output; the main agent parses it in Phase 4. If the call fails or runs out of time, record CodeRabbit as **not reviewed**, with the error, and continue with the remaining agents.

#### 3c: Codex MCP — direct tool call (if available)

Call the Codex MCP tool **directly** (no subagent wrapper) with a review prompt that includes:
- The full diff content
- The list of changed files
- Instruction to identify bugs, security issues, quality problems, and improvements
- Request the response as a list of findings with `path`, `line`, `severity`, and `description` per finding

Capture the full response — the main agent parses it in Phase 4. If the call fails, record the failure and continue with remaining agents.

#### 3d: security-auditor (Agent subagent)

Spawn the `ogxo-review:security-auditor` subagent via the Agent tool.

Provide:
- The full diff content
- The list of changed files
- Context (branch name, PR title if available)

Instruct the sub-task to run its full workflow, and, for this dispatch only, to include findings at every confidence (1-10) rather than only 8+, because Phase 6 verifies every finding and marks the wrong ones instead of dropping them.

**Required output format** — for each finding return:
- `path`: file path relative to repo root
- `line`: specific line number
- `severity`: critical | warning | suggestion
- `confidence`: 1-10 score
- `body`: clear explanation with CWE/CVE references where applicable

**Error handling**: If any reviewer fails or times out, log the failure and continue. The minimum viable review requires code-review-agent + security-auditor (both bundled in this plugin).

### Phase 4: Normalize Findings

Parse each agent's raw output into a common schema. Process each agent's results:

**Common finding schema:**
- **id**: Sequential identifier (F1, F2, ...)
- **path**: File path relative to repo root
- **line**: Line number (best effort; 0 if unmappable)
- **severity**: `critical` | `warning` | `suggestion`
- **category**: `security` | `quality` | `performance` | `testing` | `style` | `error-handling`
- **description**: Clear one-line description
- **sources**: List of agent names that reported this finding
- **raw_confidence**: Per-agent confidence scores (object keyed by agent name)

**Parsing rules per agent:**

- **code-review-agent**: Structured findings — map directly to schema
- **CodeRabbit CLI**: Parse the `--agent` output (or the `--plain` text) for file paths, line numbers, and severity. Assign synthetic confidence of 7/10 (CodeRabbit does not output confidence scores)
- **Codex MCP**: Parse text/structured response for file paths, line numbers, severity. Assign synthetic confidence of 7/10 if not provided
- **Security auditor**: Structured findings — map directly to schema

### Phase 5: Correlate Findings

Merge findings from different agents that describe the same underlying problem:

1. **Merge only the same problem.** Same file and nearby lines (within about 5) is a reason to compare two findings, not to merge them: an injection and a naming nit three lines apart are two findings. When unsure, keep them apart; Phase 6 asks the verifier.
2. **Never merge two findings from the same agent.** An agent doesn't report one issue twice.
3. **Lead with the most severe finding** of a merged group, then the most detailed; keep the others' one-line descriptions as `also reported`, so nothing an agent said disappears before verification.
4. **Union source agent names** in the `sources` field, and keep each agent's confidence.
5. **Re-number sequentially** as F1, F2, F3, ...

### Phase 6: Independent Verification

The orchestrator does not judge the findings itself: it merged them, so it is not an independent check. Every finding goes to `ogxo-review:finding-verifier`, an agent that tests each claim against the code and looks for the reason it is wrong first.

1. **Batch the claims.** About 10 claims per sub-task: keep a file's findings together, and fill a batch with related files (same directory or feature). Put findings within about 5 lines of each other from different agents in the same batch, even if Phase 5 kept them apart.
2. **Dispatch.** Spawn one sub-task per batch (`subagent_type: ogxo-review:finding-verifier`), all in the same message so they run in parallel. Give each claim's ID, `path`, `line`, severity, and claim text (description plus body, with any `also reported` lines), and how to get the diff (the Phase 1 command). Leave out the agents' reasoning and confidence scores, so the verifier forms its own view. Ask it to add, per claim, a `confidence` from 1 to 10 that the problem is real here, and to say when two claims in its batch describe the same problem.
3. **Apply the verdicts:**

   | Verdict | Status | Table |
   |---|---|---|
   | `confirmed` | `confirmed` | Take the verifier's corrected `line` or `severity` if it gave one, and note a severity change |
   | `refuted` | `likely false positive` | Keep the row, marked `FP?`, with the verifier's evidence |
   | `uncertain` | `needs review` | Mark `NR`, with what would settle it |
   | no verdict for that ID | `not verified` | List it under the table, never as confirmed or as a false positive |

   Where the verifier says two claims from different agents describe the same problem, merge them as Phase 5 does.
4. **Second look for critical findings.** A finding still `critical` after verification, or rated `critical` by its agent and not refuted, gets one more `finding-verifier` sub-task with only that claim. If it does not confirm, mark the finding `NR` with both verdicts; if it gives a different severity, take it and note the change.

The Confidence column is the verifier's score. If you disagree with a verdict, say so in a note on that finding; don't change its status.

### Phase 7: Present Unified Table

Present the full review results in this format:

```
## Full Review Summary

### Reviewed: [branch name, PR title, or "uncommitted changes"]
### Agents: N/M ran ([list]. [Note unavailable or failed])

| # | Severity | File:Line | Category | Description | CRA | CR | CDX | SEC | Confidence |
|---|----------|-----------|----------|-------------|------|----|-----|-----|------------|
| 1 | critical | src/api.ts:87 | security | SQL injection via... | X | X | | X | 9/10 |
| 2 | warning | src/auth.ts:42 | quality | Missing validation... | | X | X | | 7/10 |
| 3 | suggestion | src/utils.ts:15 | style | Extract to helper... | X | | | | 5/10 (FP?) |

Legend: CRA=code-review-agent | CR=CodeRabbit | CDX=Codex | SEC=Security Auditor
FP? = Possible false positive (the verifier refuted it) | NR = Needs review

**Not reviewed:** [each agent that failed or ran out of time, with its error]
**Not verified:** [each finding no verifier returned a verdict for: ID, file:line, severity, description]

### Stats
- Total: X findings (Y critical, Z warnings, W suggestions)
- Cross-agent agreement: N findings flagged by 2+ agents
- Possible false positives: M findings; needs review: K; not verified: U
- Severities changed by verification: [list, or "none"]
- Agents used: [list with availability status]
```

**Table rules:**
- If code-review-agent or security-auditor did not run, or ran only in part, title the summary **Partial review** and say which one is missing: this command's minimum is both
- Omit the **Not reviewed** and **Not verified** lines only when they are empty. An agent that did not run must never read as one that found nothing
- Sort by severity: critical → warning → suggestion
- Within the same severity, sort by confidence descending (highest first)
- Only include agent columns for agents that were actually dispatched
- Mark "FP?" next to confidence for findings with status `likely false positive`
- Mark "NR" (needs review) next to confidence for findings with status `needs review`

### Phase 8: Fix Option

After presenting the table, ask the user:

> Would you like me to fix the confirmed findings?
> - **all** — Fix all confirmed findings
> - **critical** — Fix only critical and warning severity
> - **pick** — Specify finding numbers (e.g., 1,2,5)
> - **none** — Done, just wanted the analysis

If the user chooses to fix:

1. Filter to the selected findings based on user choice
2. **Exclude** findings marked as "likely false positive" unless the user explicitly picks them by number
3. Read the affected files (the verifiers read them, not this conversation), apply minimal, targeted fixes for the selected findings, then run the project's tests to verify no breakage
4. After fixing, present a summary:
   - Which findings were fixed (by ID)
   - What changed in each file
   - Any findings that could not be auto-fixed (explain why)

## Quality Gates

- **Never fix without user approval** — Read-only by default, no modifications unless the user opts in
- **Confirmed means a verifier confirmed it** — Every finding goes through `finding-verifier`; refuted ones are marked "FP?", unverified ones are listed as not verified
- **Gracefully handle unavailable agents** — Minimum viable: code-review-agent + security-auditor (both bundled in this plugin); name every agent that did not run
- **Nothing disappears silently** — Merged-in findings stay as `also reported`; a finding without a verdict is listed, not dropped
- **Cross-agent agreement boosts confidence but does not double-count** — Correlation merges, not duplicates
- **No GitHub posting** — This is local analysis only. Use `/ogxo-review:code-review-git` to post findings to GitHub
- **Respect scope** — Only review files in the diff, not the entire codebase

## Usage

- `/ogxo-review:full-review` — Reviews all current changes (unstaged + staged)
- `/ogxo-review:full-review staged` — Reviews only staged changes (pre-commit check)
- `/ogxo-review:full-review uncommitted` — Reviews only unstaged changes
- `/ogxo-review:full-review 42` — Reviews PR #42's diff
- `/ogxo-review:full-review https://github.com/org/repo/pull/42` — Reviews specific PR
- `/ogxo-review:full-review feature/auth` — Reviews branch diff vs the default branch
