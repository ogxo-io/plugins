---
description: Show ogxo-route's subagent dispatch counts per agent and requested model
argument-hint: "[days]"
allowed-tools: Bash(CLAUDE_PLUGIN_DATA=*)
---

Run exactly this and show its output unchanged:

```bash
CLAUDE_PLUGIN_DATA="${CLAUDE_PLUGIN_DATA}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/stats.sh" $ARGUMENTS
```

"Requested model" is the `model` passed on the dispatch; "pin/inherit" means none was passed and the agent's own pin or the session model applied. A high "Generic dispatches with no model" count means Explore/general-purpose/Plan ran on the session model.
