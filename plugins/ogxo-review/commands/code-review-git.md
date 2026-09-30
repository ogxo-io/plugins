---
description: Run code review + security audit, post findings as GitHub PR review comments (line-by-line), and answer other reviewers' comments (👍 to agree, a reply to disagree)
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
5. Read what other reviewers have already said, and who you are relative to the PR:

```bash
read -r OWNER REPO < <(gh repo view --json owner,name --jq '"\(.owner.login) \(.name)"')
gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!) {
    viewer { login }
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        author { login }
        reviews(first: 50) {
          nodes { id state body author { login }
            reactionGroups { content viewerHasReacted } }
        }
        reviewThreads(first: 100) {
          nodes { id isResolved isOutdated path line
            comments(first: 20) {
              nodes { id body author { login } createdAt
                reactionGroups { content viewerHasReacted } }
            }
          }
        }
      }
    }
  }' -f owner="$OWNER" -f repo="$REPO" -F pr=<number>
```

   Keep `viewer.login` and `author.login`: when they match, this is the user's own PR (see Phase 6). Keep the unresolved threads and the non-empty review bodies written by anyone other than the viewer; Phase 4b answers them. A `THUMBS_UP` group with `viewerHasReacted: true` means the user already agreed with that comment.

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
4. Run test coverage tools and map uncovered lines to the PR diff, unless the project's `CLAUDE.md` or test setup shows the test command has side effects (code generation, snapshot updates, resetting a shared test database) or writes reports into the tracked tree; then report coverage as not run and give the command
5. Maintainability index per file, only when a tool computes it
6. Identify risk hotspots (high complexity + low coverage)
7. Apply its thresholds and confidence scoring — only findings 8+/10

**Output format** — same structured data as Phases 2 and 3:
- `path`, `line`, `severity`, `confidence`, `body` (with concrete metric values, thresholds, and risk assessment)

### Phase 4: Compile & Deduplicate

1. Merge findings from all three sub-tasks
2. Deduplicate overlapping findings (same file + line range) — keep the higher-confidence version
3. Sort by severity: critical → warning → suggestion
4. Assign each finding a unique ID prefixed by source: `R1`, `R2` (code review), `S1`, `S2` (security), `M1`, `M2` (metrics)

### Phase 4b: Weigh the Other Reviewers' Comments

Go through each unresolved thread and review body from Phase 1 step 5 that another reviewer (a person or a bot) wrote. Read the code it points at, then take one of four stances, each with an ID (`O1`, `O2`, ...):

| Stance | When | Action |
|---|---|---|
| **Agree** | The point holds against the current code | 👍 on their comment, so they know you agree. If one of your findings says the same thing, drop yours: the 👍 replaces it. |
| **Disagree** | The point doesn't hold (the code already handles it, it misreads the diff, the premise is wrong) | Reply in their thread with why, citing `file:line` or the behaviour you checked. |
| **Another angle** | The point is partly right, or there is a better fix or a risk they missed | Reply in their thread with the addition. If one of your findings covers it, reply instead of posting a separate comment. |
| **No view** | You can't verify it (outside the diff, needs context you don't have) | Nothing. Don't 👍 what you haven't checked. |

Skip a comment you already 👍'd, and an outdated thread whose code no longer exists. Replies are short and specific: say what you checked and what follows, not a restatement of their comment. A review body has no thread to reply in, so a disagreement with one goes into your own review body, addressed to them by `@login`. Never resolve another reviewer's thread; that is theirs or the PR author's call.

### Phase 4c: Verify Before Presenting

Everything this command posts is public, so every finding and every stance from Phase 4b gets a second opinion from an agent that didn't produce it. Group the claims by file and spawn one **finding-verifier** sub-task per file (`subagent_type: ogxo-review:finding-verifier`), all in the same message so they run in parallel.

Give each sub-task the claims for its file: ID, `path`, `line`, severity, and the claim text; for an `O` item, the other reviewer's point and your intended stance. Leave out the reasoning the reviewing agents gave, so the verifier forms its own view.

Apply the verdicts:

| Verdict | Finding (`R`/`S`/`M`) | Response to a reviewer (`O`) |
|---|---|---|
| `confirmed` | Keep. Take the verifier's corrected `line` or `severity` if it gave one. | Keep the stance. |
| `refuted` | Drop it from the table. List it under "Dropped by verification" with the verifier's evidence. | Drop the 👍 or the reply. If the verifier showed their point is right after all, switch a disagreement to 👍; if it showed their point is wrong, switch an agreement to a reply that says why. |
| `uncertain` | Keep it, marked `?`, with what would settle it. | Don't 👍 or reply; list it for the user. |

### Phase 5: Present Summary to User

Before posting to GitHub, present the compiled review to the user:

```
## Review Summary for PR #<number>

| ID | Severity | Confidence | Verified | File | Line | Finding |
|----|----------|------------|----------|------|------|---------|
| S1 | critical | 9/10 | ✓ | src/api.ts | 87 | SQL injection via unsanitized... |
| R1 | warning  | 8/10 | ✓ | src/auth.ts | 42 | Missing input validation on... |
| R2 | suggestion | 9/10 | ? | src/utils.ts | 15 | Consider extracting to helper... (depends on whether X is called elsewhere) |

Total: X findings (Y critical, Z warnings, W suggestions)

Dropped by verification: R3 (src/db.ts:12, input is validated in routes/user.ts:8), M2 (...)

## Responses to other reviewers

| ID | Reviewer | Where | Their point | Stance | Action |
|----|----------|-------|-------------|--------|--------|
| O1 | @alice | src/api.ts:87 | Query isn't parameterized | Agree | 👍 (replaces S1) |
| O2 | @bob | src/cache.ts:20 | TTL should be 60s | Disagree | Reply: "The 5s TTL matches..." |
```

Show each reply's full text. If this is the user's own PR, say so, and that the review will be posted as `COMMENT` (Phase 6).

**Wait for user approval before posting to GitHub.**

The user may:
- Approve all findings and responses → proceed to Phase 6
- Remove specific findings or responses by ID → exclude them
- Edit specific findings or replies → modify before posting
- Cancel → abort without posting

### Phase 6: Post Review to GitHub

Use the GitHub CLI to submit a **pull request review** with line-level comments.

Write the payload to a JSON file and post it with `gh api --input`; inline `--field` breaks on the markdown, backticks, code suggestions, and nested quotes in comment bodies.

**Step 1**: Create the review payload at `/tmp/pr-review-{owner}-{repo}-{pr_number}.json` using the **Write tool**. The name carries the PR, so reviews of different PRs running at the same time write separate files:

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
  --input /tmp/pr-review-{owner}-{repo}-{pr_number}.json
```

**Important rules for posting:**
- Use `side: "RIGHT"` (new file version) for all comments
- **Map every `line` to the diff before posting.** In `gh pr diff <number>`, each hunk header `@@ -a,b +c,d @@` makes new-file lines `c` through `c+d-1` commentable (added and context lines). A line outside every hunk can't take an inline comment: put that finding in the review `body` as `path:line` instead.
- **A multi-line comment** (a suggestion that replaces several lines) sets `start_line` to the first line and `line` to the last, with `start_side: "RIGHT"`; both lines must be in the same hunk. The ` ```suggestion ` block then replaces that whole range.
- Use GitHub's suggestion syntax (` ```suggestion `) when proposing concrete code fixes
- Prefix each comment body with the severity emoji: 🔴 Critical | 🟡 Warning | 💡 Suggestion
- Include the finding ID (R1, S1, etc.) in each comment for traceability
- Choose the `event` from the Severity → Review Event table below, counting only verified (✓) findings: an uncertain (`?`) critical posts as `COMMENT`
- **On the user's own PR** (`viewer.login` equals `author.login` from Phase 1), GitHub refuses `REQUEST_CHANGES` and `APPROVE` from the author with a 422. Post `COMMENT`, and open the body with the verdict the table would have given ("Would request changes: 1 critical finding").
- Post as a **single review** (one API call), not individual comments

**If the POST fails with 422**, nothing was posted: GitHub rejects the whole review when any one comment can't be placed ("Line could not be resolved", "must be part of the diff"). Re-check each comment's `line` (and `start_line`) against the hunks, move the ones that don't map into the review `body`, and post again once. Then report which findings were moved.

**Step 3**: Post the approved responses to other reviewers (Phase 4b), one call each, and check each result has no `errors` array. Pass text through GraphQL variables with `-f`, never inside the query string.

A 👍 on their comment (`subjectId` is the comment's `PRRC_...` id, or the review's `PRR_...` id for a review body):

```bash
gh api graphql \
  -f query='mutation($id: ID!) {
    addReaction(input: {subjectId: $id, content: THUMBS_UP}) { reaction { content } }
  }' \
  -f id="PRRC_..."
```

A reply in their thread (`PRRT_...` thread id):

```bash
gh api graphql \
  -f query='mutation($threadId: ID!, $body: String!) {
    addPullRequestReviewThreadReply(input: {
      pullRequestReviewThreadId: $threadId
      body: $body
    }) { comment { url } }
  }' \
  -f threadId="PRRT_..." \
  -f body="The reply text"
```

**Step 4**: Output the review URL and each reply's URL so the user can verify.

### Phase 7: Final Report

```
## Review Posted

- PR: #<number> (<title>)
- Review URL: <link>
- Findings posted: X inline comments
- Findings in summary: Y (couldn't map to diff lines)
- Dropped by verification: D
- Review type: COMMENT | REQUEST_CHANGES | APPROVE (own PR: COMMENT, with the verdict in the body)
- Other reviewers: A agreed (👍), B replied to, C left without a view
- Code quality findings: X (from code-review-agent)
- Security findings: Y (from security-auditor)
- Metrics findings: Z (from code-metrics-analyst)
```

## Quality Gates

- **Never post without user approval** — Always present findings first
- **Never post false positives** — Only confidence 8+ findings (each agent is instructed to report only 8+)
- **Verify before presenting** — every finding and every response to another reviewer goes through Phase 4c; nothing refuted is posted
- **Use REQUEST_CHANGES only when a verified critical finding exists** (see the table below)
- **Map lines accurately** — Verify each line exists in the diff before posting
- **Single review submission** — Post all comments in one review, not individual comments
- **Don't repeat another reviewer** — agree with their comment (👍) instead of posting the same finding again
- **Never resolve another reviewer's thread**
- **Respect PR scope** — Only review files changed in the PR, not the entire codebase
- **Trust the agents** — All three sub-tasks use their own filtering, thresholds, and scoring rules

## Severity → Review Event Mapping

| Highest Severity | GitHub Review Event | Meaning |
|-----------------|-------------------|---------|
| Critical (verified) | `REQUEST_CHANGES` | Blocks merge until addressed |
| Warning | `COMMENT` | Should be addressed but non-blocking |
| Suggestion only | `COMMENT` | Nice-to-have improvements |
| No issues found | `APPROVE` | Code looks good, nothing to flag |

## Usage

Examples:
- `/ogxo-review:code-review-git` → Reviews PR from current branch
- `/ogxo-review:code-review-git 42` → Reviews PR #42
- `/ogxo-review:code-review-git https://github.com/org/repo/pull/42` → Reviews specific PR URL
