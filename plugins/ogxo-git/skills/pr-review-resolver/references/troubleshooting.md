# Troubleshooting Guide for PR Review Resolution

Reference file for the `pr-review-resolver` skill. Contains solutions for common issues encountered during the workflow.

## Common Issues

| Situation | Action |
|-----------|--------|
| `gh` CLI not installed | Inform user to install from https://cli.github.com/ |
| `gh` not authenticated | Run `gh auth login` and retry |
| PR not found from branch | Ask user for PR number or URL |
| No review comments found | Inform user there are no pending review comments |
| API rate limit hit | Wait and retry, or inform user |
| Cannot resolve thread (permissions) | User may not have permission; skip resolution and inform |
| Comment references deleted file | Classify as "Already Addressed" and reply explaining the file was removed |
| Outdated diff hunk | Read the current file state, not the diff; note if the code has changed significantly |

## REST API Pitfalls

### 404 on Reply Endpoint

The REST reply endpoint requires the PR number in the path:

```bash
# CORRECT — includes PR number:
gh api repos/{owner}/{repo}/pulls/{pr}/comments/{comment_id}/replies -f body="Reply"

# WRONG — missing PR number, returns 404:
gh api repos/{owner}/{repo}/pulls/comments/{comment_id}/replies -f body="Reply"
```

### Missing Pagination Causes False "Unreplied" Detection

Without `--paginate`, only the first page of comments is returned (typically 30 items). This causes comments on later pages to appear as if they have no replies, triggering duplicate replies.

```bash
# WRONG — only gets first page:
gh api repos/{owner}/{repo}/pulls/{pr}/comments --jq '...'

# CORRECT — gets all pages:
gh api repos/{owner}/{repo}/pulls/{pr}/comments --paginate --jq '...'
```

### Posting Test Content to Debug Endpoints

**NEVER** post throwaway content like "test", "check", or "hello" to verify if an endpoint works. These create real replies visible to reviewers. Instead:

```bash
# Use a GET request to verify the endpoint exists:
gh api repos/{owner}/{repo}/pulls/{pr}/comments/{comment_id} --method GET

# Or use --method HEAD to check without fetching the body:
gh api repos/{owner}/{repo}/pulls/{pr}/comments/{comment_id} --method HEAD
```

### Confusing PR Comments with PR Review Comments

- `issues/{pr}/comments` or `gh pr comment` — general PR comments (not line-level)
- `pulls/{pr}/comments` — inline review comments on specific code lines
- These are **different APIs**. Using the wrong one will return unexpected results.

## GraphQL API Issues

### Thread Resolution Fails

If `resolveReviewThread` mutation returns an error:
- Verify the `threadId` is a valid GraphQL node ID (not a REST API numeric ID)
- Check that the authenticated user has write access to the repository
- Some organizations restrict thread resolution to specific roles

### Pagination for Large PRs

If a PR has more than 100 review threads:
```bash
# Use cursor-based pagination
gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!, $cursor: String) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100, after: $cursor) {
          pageInfo {
            hasNextPage
            endCursor
          }
          nodes {
            id
            isResolved
            comments(first: 1) {
              nodes { body path line }
            }
          }
        }
      }
    }
  }
' -f owner="$OWNER" -f repo="$REPO" -F pr="$PR_NUMBER"
```

### Reply Mutation Silently Fails

If `addPullRequestReviewThreadReply` returns errors or no `comment.id`:
- **Most common cause**: The reply body was embedded directly in the query string instead of using GraphQL variables. Double quotes, newlines, markdown links, and backticks break the mutation silently. Always use `-f body="..."` as a variable.
- Verify the `threadId` is a valid GraphQL node ID (`PRRT_...` format), not a REST API numeric ID
- Check the thread still exists (it may have been deleted or the PR was closed)
- Ensure the PR is still open — closed PRs may restrict new comments
- Check the response for specific error messages (e.g., permissions, not found)

## Git and Branch Issues

### Current Branch Doesn't Match PR

If the local branch doesn't match the PR head branch:
- Warn the user that changes will be on a different branch
- Ask if they want to switch branches first
- Never auto-switch branches without user approval

### Merge Conflicts After Fixes

If fixes cause merge conflicts with the base branch:
- Inform the user about the conflict
- Do not attempt to resolve merge conflicts automatically
- Suggest the user rebase or merge the base branch first

## Edge Cases

### Comments on Lines That No Longer Exist

When a reviewer commented on code that has since been modified or removed:
- Read the current file state (not the outdated diff)
- If the concern was addressed by the subsequent changes, classify as "Already Addressed"
- If the file was deleted entirely, note this in the reply

### Multiple Comments on the Same Line

When multiple reviewers comment on the same code:
- Address each comment independently
- If comments conflict, flag as "Needs Discussion" and present both perspectives
- Apply the fix that satisfies the most concerns

### Self-Reviews

If the PR author left review comments on their own PR:
- These are usually notes or TODOs, not external feedback
- Ask the user how they want to handle self-review comments
