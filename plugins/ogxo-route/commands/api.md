---
description: Run one task as a headless claude -p billed to an Anthropic API key instead of your Claude subscription, at a chosen model, effort, and budget
argument-hint: "key | status | [--model m] [--effort e] [--budget usd] [--write] [--tools \"list\"] [--] <task>"
allowed-tools: Bash(bash *)
---

Run exactly this and show its output. Unless the arguments are `key`, `status`, or empty, set the Bash tool's `run_in_background` (a run can take longer than the Bash timeout) and show the output when it finishes:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/api.sh" <<'OGXO_ROUTE_API_ARGS'
$ARGUMENTS
OGXO_ROUTE_API_ARGS
```

The run is a separate process: it does not see this conversation, only the task text and the project's CLAUDE.md. It runs in `dontAsk` mode with a read-only tool list unless `--write` (adds Edit and Write) or `--tools` is given. Its result is the worker's final message followed by its cost; treat it like any other worker's report.
