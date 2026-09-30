# ogxo-review

Multi-agent code review: full-review cross-correlates several reviewers and filters false positives; code-review-git posts line-level findings as a GitHub PR review and answers other reviewers' comments. Bundles the code-review-agent, security-auditor, code-metrics-analyst, and finding-verifier agents; code-review-git verifies every finding before it is shown.

## Install

```bash
claude plugin marketplace add ogxo-io/plugins
claude plugin install ogxo-review@ogxo
```

## Contents

- `/ogxo-review:code-review-git` (command)
- `/ogxo-review:full-review` (command)
- `ogxo-review:code-metrics-analyst` (agent)
- `ogxo-review:code-review-agent` (agent)
- `ogxo-review:security-auditor` (agent)
- `/ogxo-review:security-check` (command)
- `ogxo-review:dependency-auditor` (agent)
- `ogxo-review:finding-verifier` (agent)

## Review behaviour

- `code-review-agent` has a **re-review mode**: give it the prior findings and the range since the last review, and it returns fixed, not fixed, or partly fixed per finding, plus only the new defects the fix introduced.
- Each finding says whether it was verified by running a command or by reading the code. Test commands with side effects (code generation, snapshot updates, shared test-database resets) are not run; the finding gives the command instead. `code-review-git` skips its coverage run for the same reason.
- A test that would pass without the change it covers is reported as vacuous. The test-file exclusions in `code-review-agent`, `security-auditor`, and `security-check` apply to security findings only.
- `code-review-git` writes its review payload to a file named after the owner, repository, and PR number, so parallel reviews of different PRs don't share one file.
