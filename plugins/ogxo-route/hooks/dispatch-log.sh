#!/usr/bin/env bash
# PostToolUse (Agent|Task): append one line per subagent dispatch to
# ${CLAUDE_PLUGIN_DATA}/dispatches.jsonl for /ogxo-route:stats. Append-only:
# parallel dispatches each append one line; pruning happens in stats.sh.
# agent_type is the dispatching subagent when nested (null at top level).
# Logs no prompt text and no paths. Never fails the session.
command -v jq >/dev/null 2>&1 || { echo "ogxo-route/dispatch-log: jq not found; this hook is inactive. Install jq to enable it." >&2; exit 1; }
[ -n "${CLAUDE_PLUGIN_DATA:-}" ] || exit 0
mkdir -p "$CLAUDE_PLUGIN_DATA" 2>/dev/null || exit 0

line=$(jq -c '{
  ts: (now | floor),
  session_id: (.session_id // null),
  subagent_type: (.tool_input.subagent_type // ""),
  requested_model: (.tool_input.model // null),
  nested: ((.agent_id // null) != null),
  agent_type: (.agent_type // null)
}' 2>/dev/null) || exit 0
[ -n "$line" ] || exit 0
printf '%s\n' "$line" >>"$CLAUDE_PLUGIN_DATA/dispatches.jsonl" 2>/dev/null
exit 0
