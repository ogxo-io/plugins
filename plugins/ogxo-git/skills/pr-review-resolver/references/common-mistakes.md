# Common Mistakes to Avoid

Reference file for the `pr-review-resolver` skill. Each entry pairs a wrong
approach with the correct one. The core rules these reinforce also live inline
in the SKILL.md workflow — this file is the detailed catalog.

## Mistake 1: Auto-Fixing Without Analysis

**Wrong:** Immediately start editing files based on comment text alone.
**Correct:** Read the full context, classify the comment, present analysis, then fix after approval.

## Mistake 2: Dismissive Replies

**Wrong:** "That's not necessary" or "Works fine as-is"
**Correct:** "Thanks for flagging this! I kept [approach] because [reasoning]. Happy to discuss if you see a concern I'm missing."

## Mistake 3: Resolving "Needs Discussion" Threads

**Wrong:** Resolve threads that have genuine trade-offs or require team input.
**Correct:** Leave them open and reply with your perspective to facilitate discussion.

## Mistake 4: Bulk Resolving Without Replies

**Wrong:** Resolve all threads at once without posting replies.
**Correct:** Every resolved thread must have either a code fix pushed or a reply posted.

## Mistake 5: Pushing Without User Approval

**Wrong:** Auto-push after making fixes.
**Correct:** Always ask before pushing changes to the remote.

## Mistake 6: Dismissing Out-of-Scope Issues Without Tracking

**Wrong:** Reply "This is outside the scope of this PR" and move on.
**Correct:** Create a GitHub issue to track the concern, reply with the issue link, then resolve the thread.

## Mistake 7: Accepting Reviewer Claims Without Verification

**Wrong:** Classify as "Valid Fix" because the reviewer says there's a bug, without understanding the full context.
**Correct:** Read the actual code, trace the call path, and verify the concern is valid. The reviewer may not see upstream null checks, type constraints, or architectural patterns that already handle the case.

## Mistake 8: Deferring Bugs in Code the PR Modifies or Tests

**Wrong:** Reviewer says "this function has a bug" on a test PR, and you reply "The bug is in existing code, not part of this PR's changes. Created issue #123 to track."
**Correct:** If your PR adds tests for a function or modifies it, you own its correctness. Fix the bug in this PR or at minimum make the tests expose the bug (failing tests) so it's visibly tracked. Do not create a separate issue and move on — that's evasion.

## Mistake 9: Posting Test Content to Debug API Endpoints

**Wrong:** Post `-f body="test"` to verify an endpoint works, creating junk replies on real PRs.
**Correct:** Use a GET request or `--method HEAD` to verify the endpoint exists before posting real content.

## Mistake 10: Using Wrong REST Endpoint for Review Comment Replies

**Wrong:** `gh api repos/{owner}/{repo}/pulls/comments/{id}/replies` (missing PR number — returns 404).
**Correct:** `gh api repos/{owner}/{repo}/pulls/{pr}/comments/{id}/replies` (includes PR number).

## Mistake 11: Fetching Comments Without Pagination

**Wrong:** `gh api repos/{owner}/{repo}/pulls/{pr}/comments` (gets only first page — comments appear unreplied).
**Correct:** `gh api repos/{owner}/{repo}/pulls/{pr}/comments --paginate` (gets all pages).

## Mistake 12: Tests That Validate Wrong Behavior

**Wrong:** Reviewer says "these tests assert the wrong expected values" and you reply "the tests match the current code behavior."
**Correct:** Tests should verify CORRECT behavior, not current behavior. If the code has a bug, tests must expose it. Acknowledge the reviewer's finding, fix the code, and update the test expectations to match correct behavior.
