---
description: Mark grok or codex off for ogxo-route's routing (quota or login ran out), back on, or show status
argument-hint: "[on|off grok|codex [hours]]"
allowed-tools: Bash(CLAUDE_PLUGIN_DATA=*)
---

Run exactly this and show its output:

```bash
CLAUDE_PLUGIN_DATA="${CLAUDE_PLUGIN_DATA}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/external.sh" $ARGUMENTS
```

"off" affects routing only. A grok or codex run the user asks for by name still goes through its bridge.
