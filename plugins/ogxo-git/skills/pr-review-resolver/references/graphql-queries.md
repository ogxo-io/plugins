# GraphQL Query Templates for PR Review Resolution

Reference file for the `pr-review-resolver` skill. Contains GraphQL and CLI query templates used in the workflow.

> **Key principle**: Use **GraphQL** for thread replies and resolution; the REST reply endpoint is the fallback and needs the PR number in its path. Thread IDs (`PRRT_...`) are the key identifier for both operations.

## Step 0: Detect Repository Owner and Name

```bash
# Detect owner/repo from the git remote
REPO_FULL="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
# Result format: "owner/repo"
```

Extract owner and repo separately (needed for GraphQL variables):

```bash
OWNER="${REPO_FULL%%/*}"
REPO="${REPO_FULL##*/}"
```

## Step 1: Identify the Pull Request

```bash
# Option A: PR number provided as argument
PR_NUMBER="$ARGUMENTS"

# Option B: Detect from current branch
gh pr view --json number,title,url,state --jq '.number'

# Option C: List open PRs for the user to choose
gh pr list --author @me --state open
```

**Verify PR state:**
```bash
gh pr view "$PR_NUMBER" --json state,title,url,headRefName
```

## Step 2: Fetch Unresolved Review Comments

### 2a. Fetch unresolved threads with thread IDs (required)

```bash
# GraphQL returns thread IDs (PRRT_...) needed for replies and resolution
gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            path
            line
            comments(first: 10) {
              nodes {
                id
                body
                author { login }
                createdAt
              }
            }
          }
        }
      }
    }
  }
' -f owner="$OWNER" -f repo="$REPO" -F pr="$PR_NUMBER"
```

**Important**: The `id` field on each thread node is the thread ID (`PRRT_...`). Save these — they are used for both replying and resolving.

### 2b. Quick fetch via gh CLI (for simpler cases)

```bash
# Simpler but does not return thread IDs — use 2a instead when you need to reply
gh pr view "$PR_NUMBER" --json reviewThreads \
  --jq '.reviewThreads[] | select(.isResolved == false) | {
    path: .path,
    line: .line,
    isOutdated: .isOutdated,
    comments: [.comments[] | {
      id: .id,
      body: .body,
      author: .author.login,
      createdAt: .createdAt
    }]
  }'
```

### 2c. Supplement with REST API (if more detail is needed)

> **IMPORTANT**: Always use `--paginate` to fetch all comments. Without it, only the first page is returned and comments on later pages appear unreplied.

```bash
# Get all review comments with diff hunks and line context
# NOTE: --paginate is REQUIRED to get all pages
gh api "repos/$REPO_FULL/pulls/$PR_NUMBER/comments" --paginate \
  --jq '.[] | {
    id: .id,
    path: .path,
    line: .line,
    original_line: .original_line,
    side: .side,
    body: .body,
    user: .user.login,
    created_at: .created_at,
    in_reply_to_id: .in_reply_to_id,
    subject_type: .subject_type,
    diff_hunk: .diff_hunk
  }'

# Identify which comments already have replies
# (to avoid falsely marking comments as unreplied)
gh api "repos/$REPO_FULL/pulls/$PR_NUMBER/comments" --paginate \
  --jq '.[] | select(.in_reply_to_id != null) | .in_reply_to_id' | sort -u
```

### Two Types of PR Comments (Do NOT Confuse)

These are **different APIs with different endpoints**. This skill deals primarily
with **PR review comments** (inline code comments from reviews).

| Type | REST Endpoint | CLI Shorthand | What It Is |
|------|--------------|---------------|------------|
| **PR comments** | `issues/{pr}/comments` | `gh pr comment` | General comments on the PR, not attached to code lines |
| **PR review comments** | `pulls/{pr}/comments` | (no shorthand) | Inline comments on specific code lines, created during reviews |

Review comment replies use `pulls/{pr}/comments/{id}/replies` — the `{pr}` number
is **required** in the path (omitting it returns 404).

**General (non-line-level) PR comment:**

```bash
gh pr comment {pr} --body "Comment text"
```

Use `gh pr comment` only for PR-level replies, never for inline review threads.

## Step 6: Post Replies

> **CRITICAL**: Always use **GraphQL variables** for the thread ID and reply body. Do NOT embed the body directly in the query string — double quotes, newlines, markdown links, and backticks will silently break the mutation. Use the REST reply endpoint (`/pulls/{pr}/comments/{id}/replies`) only as a fallback when thread IDs are unavailable; it 404s when the PR number is missing.

### Reply using variables (always use this pattern)

```bash
gh api graphql \
  -f query='mutation($threadId: ID!, $body: String!) {
    addPullRequestReviewThreadReply(input: {
      pullRequestReviewThreadId: $threadId
      body: $body
    }) { comment { id } }
  }' \
  -f threadId="PRRT_..." \
  -f body="Fixed — [brief description of what was changed]."
```

This works with any content in the body: backticks, quotes, newlines, markdown links, code blocks, regex — `gh` handles all escaping via the `-f` variable binding.

### Verify reply succeeded

Check the response for `comment.id` — if the response contains an `errors` array instead, the reply was not posted. Retry once before moving on.

### Reply templates by classification

| Classification | Reply Body |
|---------------|------------|
| **Valid Fix** | `"Fixed — [brief description of what was changed]."` |
| **Valid Suggestion** | `"Good call — [description of improvement applied]."` |
| **Declined** | `"[Diplomatic explanation with reasoning why this doesn't apply]"` |
| **Already Addressed** | `"This was addressed in [commit hash] — [brief description]."` |
| **Question** | `"[Clear, helpful answer to the question]"` |
| **Needs Discussion** | `"[Acknowledge complexity, present trade-offs, ask for team input]"` |
| **Deferred (Tracked)** | `"Valid point — created [#issue](url) to track this. Outside this PR's scope but will be addressed."` |

## Step 7: Resolve Conversation Threads

### Resolve one thread at a time (recommended)

Resolve threads individually so failures are isolated and verifiable:

```bash
gh api graphql \
  -f query='mutation($threadId: ID!) {
    resolveReviewThread(input: {threadId: $threadId}) {
      thread { id isResolved }
    }
  }' \
  -f threadId="PRRT_..."
```

Verify each response shows `isResolved: true`. If resolution fails for a thread, log the error and continue with the remaining threads.

### Batch resolve (optional — use only if many threads)

Use GraphQL aliases with variables to resolve multiple threads in one call. Note: if one thread fails, the entire batch may fail depending on the error.

```bash
gh api graphql -f query='
  mutation {
    t1: resolveReviewThread(input: {threadId: "PRRT_..._one"}) {
      thread { isResolved }
    }
    t2: resolveReviewThread(input: {threadId: "PRRT_..._two"}) {
      thread { isResolved }
    }
  }'
```

If a batch fails, fall back to resolving threads individually.

### Resolution Rules

**Only resolve threads that were:**
- Fixed with a code change
- Answered with a clear reply (for questions)
- Already addressed in previous commits
- Deferred with a GitHub issue created (link included in the reply)

**Do NOT resolve threads that:**
- Are classified as "Needs Discussion" (leave open for team input)
- Were declined without user approval to resolve
- Have unresolved sub-threads or ongoing conversation

## Step 5e: Create GitHub Issues for Deferred Items

Use `gh issue create` to track legitimate out-of-scope concerns identified during PR review.

### Basic issue creation

```bash
gh issue create \
  --title "Brief description of the issue" \
  --body "$(cat <<'EOF'
## Context

Identified during PR #[number] review by @[reviewer].

**File:** `[path]:[line]`
**Reviewer comment:** [summary of the concern]

## Details

[Description of the issue and why it matters]

_Tracked from PR review — not in scope for the original PR but should be addressed._
EOF
)"
```

### With optional label (graceful fallback)

```bash
# Try with label first
gh issue create \
  --title "Brief description" \
  --body "Issue body..." \
  --label "tech-debt" 2>/dev/null \
|| gh issue create \
  --title "Brief description" \
  --body "Issue body..."
```

If the `tech-debt` label doesn't exist in the repository, the first command fails silently and the fallback creates the issue without a label.

### Capturing the issue URL

`gh issue create` prints the issue URL to stdout on success:

```bash
ISSUE_URL="$(gh issue create --title "..." --body "...")"
# Result: https://github.com/owner/repo/issues/99
```

Use the captured URL in the Deferred (Tracked) reply template for Step 6.
