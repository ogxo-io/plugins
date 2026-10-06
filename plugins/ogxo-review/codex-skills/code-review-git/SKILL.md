---
name: code-review-git
description: "Review a GitHub PR, verify proposed findings and responses, and publish a single review only when approved."
---

# GitHub PR Review

## Workers and procedures

Read the native specialist skill or its corresponding `../../agents/<name>.md` relative to this skill directory. Agent markdown supplies a workflow, not host configuration: ignore Claude model/tool metadata and resolve plugin-root references against `../..`. Use available worker tools with plain prompts that include repository, exact scope, diff commands, read-only instruction, and output fields. Respect concurrency limits and queue work as needed. If worker tools are unavailable, perform separate sequential passes and disclose the lack of independent verification. Optional external reviewers run only when their actual CLI/tool is available; do not invent a Codex MCP or Claude Agent API.

1. Resolve the PR number/URL from the user request or `gh pr view`. Read `gh repo view --json nameWithOwner`, PR metadata (including author and `headRefOid`), `gh api user`, the complete `gh pr diff <PR>`, current reviews/comments, and review threads via paginated GitHub API reads. Keep errors visible. If the PR diff is empty, report its scope and stop.
2. Review the PR head files and changed hunks using `../../agents/code-review-agent.md`, `../../agents/security-auditor.md`, and `../../agents/code-metrics-analyst.md` as distinct procedures. Use native workers if available; otherwise perform sequential passes. Run coverage only within the user's permitted scope; label unavailable measurements.
3. Deduplicate findings and compare with existing reviewer comments. Draft agreements/disagreements rather than repeat the same finding. Read `../../agents/finding-verifier.md` and verify every finding and every proposed stance against source evidence. Drop refuted claims and mark uncertain ones. Keep the PR scope unchanged and do not resolve other reviewers' threads.
4. Prepare a single review with severity, IDs, evidence, and suggested changes. Map inline comments to RIGHT/LEFT diff hunks at the captured head SHA; move findings without a valid inline position into the summary. Use REQUEST_CHANGES only for verified critical findings, COMMENT for warnings/suggestions/uncertainty, and APPROVE only if review evidence supports it. For the viewer's own PR use COMMENT, stating the verdict GitHub would otherwise disallow.
5. Present the exact review body, inline comments, reactions/replies, and event for user approval before publishing, unless this exact publication is already authorized. Re-read `headRefOid` before posting; if it changed, re-review affected findings and update the draft.
6. Save the approved review JSON to a temporary file and post with `gh api repos/<owner>/<repo>/pulls/<number>/reviews --method POST --input <file>` using `commit_id`, `event`, `body`, and valid comments. Inspect response/errors. A 422 invalid line rejects the review: repair positions or move them to the body and retry once. Send approved replies/reactions separately with structured arguments; check GraphQL errors. Return actual review/reply URLs and a summary of what posted. No attribution text.
