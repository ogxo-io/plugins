# ogxo-review

Multi-agent code review: full-review cross-correlates several reviewers and filters false positives; code-review-git posts line-level findings as a GitHub PR review. Bundles the code-review-agent, security-auditor, and code-metrics-analyst agents.

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
