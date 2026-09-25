---
description: Multi-agent code review with cross-correlation and false positive detection
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(git show:*), Bash(git remote show:*), Bash(grep:*), Bash(which coderabbit:*), Bash(coderabbit:*), Bash(npm audit:*), Bash(cargo audit:*), Bash(pip-audit:*), Bash(govulncheck:*), Bash(gh pr view:*), Bash(gh pr diff:*), Read, Edit, Glob, Grep, Agent, mcp__codex__codex
argument-hint: "[PR number | URL | branch | staged | uncommitted]"
---

# Full Review

You are a multi-agent review orchestrator. You dispatch up to 4 independent review agents in parallel, normalize and correlate their findings, validate for false positives with independent code inspection, and present a unified cross-agent table with an option to fix.

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
| 3b | CodeRabbit CLI | Direct `Bash` call | Single CLI invocation, no reasoning needed |
| 3c | Codex MCP | Direct `mcp__codex__codex` call | Single MCP call with the diff |
| 3d | security-auditor | `Agent` subagent (`ogxo-review:security-auditor`) | Multi-step SAST + dependency scan workflow |

All four calls go in the same assistant message.

#### 3a: code-review-agent (Agent subagent)

Spawn the `ogxo-review:code-review-agent` subagent for a comprehensive review of the diff.

Provide:
- The full diff content
- The list of changed files
- Branch/PR context (title, base branch)

Instruct the sub-task to run its full workflow, and, for this dispatch only, to include findings at every confidence (1-10) rather than only 8+, because this orchestrator marks low-confidence findings as FP? in Phase 6 instead of dropping them.

**Required output format** — for each finding return:
- `path`: file path relative to repo root
- `line`: specific line number in the new version of the file
- `severity`: critical | warning | suggestion
- `confidence`: 1-10 score
- `body`: clear explanation with context, impact, and recommendation

#### 3b: CodeRabbit CLI — direct Bash call (if available)

Call `Bash` **directly** (no subagent wrapper). **Always pass `--plain`** to get non-interactive text output (the default interactive mode will hang in a subprocess). Set a 120-second timeout on the Bash call.

Commands by context:
- **All changes (default)**: `coderabbit review --plain`
- **Uncommitted only**: `coderabbit review --plain --type uncommitted`
- **Committed only**: `coderabbit review --plain --type committed`
- **Specific base branch**: `coderabbit review --plain --base <base>`

Capture the full CLI text output — the main agent parses it in Phase 4. If the call fails or times out, record the failure and continue with remaining agents.

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

Instruct the sub-task to run its full workflow, and, for this dispatch only, to include findings at every confidence (1-10) rather than only 8+, because this orchestrator marks low-confidence findings as FP? in Phase 6 instead of dropping them.

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
- **CodeRabbit CLI**: Parse text output for file paths, line numbers, and severity keywords. Assign synthetic confidence of 7/10 (CodeRabbit does not output confidence scores)
- **Codex MCP**: Parse text/structured response for file paths, line numbers, severity. Assign synthetic confidence of 7/10 if not provided
- **Security auditor**: Structured findings — map directly to schema

### Phase 5: Correlate Findings

Group findings that reference the same underlying issue:

1. **Same file + line range** (within 5 lines of each other): merge into a single finding, union the `sources` lists
2. **Same description pattern** across agents (same file, clearly describing the same issue even if line numbers differ slightly): merge if unambiguously the same issue
3. **Keep the most detailed description** from among the merged findings
4. **Union source agent names** in the `sources` field
5. **Re-number sequentially** as F1, F2, F3, ...

After correlation, each finding has:
- A merged description (most detailed version)
- A `sources` list showing which agents flagged it
- The agents' confidence scores

### Phase 6: Independent Validation

For each correlated finding, the orchestrator independently validates:

1. **Read the actual file** at the flagged line — get fresh context beyond the diff (surrounding code, imports, framework patterns, project conventions)
2. **Assess independently** whether the finding is real given full context
3. **Assign orchestrator confidence** (1-10):
   - **9-10**: Clearly real issue, code confirms the problem
   - **7-8**: Likely real, evidence supports the finding
   - **5-6**: Uncertain, could go either way
   - **1-4**: Likely false positive, context contradicts the finding
4. **Set status**:
   - `confirmed` — high confidence, real issue
   - `likely false positive` — low confidence, context contradicts
   - `needs review` — uncertain, human judgment needed

**Confidence heuristics:**

- Agreement across agents is evidence, not proof; single-agent findings need direct code confirmation
- **Orchestrator disagrees with a single-agent finding** → mark as "FP?" and lower confidence

The final confidence score is the orchestrator's independent assessment, informed by both the agent reports and direct code inspection.

### Phase 7: Present Unified Table

Present the full review results in this format:

```
## Full Review Summary

### Reviewed: [branch name, PR title, or "uncommitted changes"]
### Agents: N/M available ([list]. [Note unavailable])

| # | Severity | File:Line | Category | Description | CRA | CR | CDX | SEC | Confidence |
|---|----------|-----------|----------|-------------|------|----|-----|-----|------------|
| 1 | critical | src/api.ts:87 | security | SQL injection via... | X | X | | X | 9/10 |
| 2 | warning | src/auth.ts:42 | quality | Missing validation... | | X | X | | 7/10 |
| 3 | suggestion | src/utils.ts:15 | style | Extract to helper... | X | | | | 5/10 (FP?) |

Legend: CRA=code-review-agent | CR=CodeRabbit | CDX=Codex | SEC=Security Auditor
FP? = Possible false positive (low confidence, single agent)

### Stats
- Total: X findings (Y critical, Z warnings, W suggestions)
- Cross-agent agreement: N findings flagged by 2+ agents
- Possible false positives: M findings
- Agents used: [list with availability status]
```

**Table rules:**
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
3. Apply minimal, targeted fixes yourself for the selected findings (you already read the affected files in Phase 6), then run the project's tests to verify no breakage
4. After fixing, present a summary:
   - Which findings were fixed (by ID)
   - What changed in each file
   - Any findings that could not be auto-fixed (explain why)

## Quality Gates

- **Never fix without user approval** — Read-only by default, no modifications unless the user opts in
- **Never present false positives as confirmed** — Mark low-confidence single-agent findings with "FP?"
- **Gracefully handle unavailable agents** — Minimum viable: code-review-agent + security-auditor (both bundled in this plugin)
- **Single-agent low-confidence → flagged, not silently confirmed** — Transparency over false certainty
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
