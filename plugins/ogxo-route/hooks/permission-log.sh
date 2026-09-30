#!/usr/bin/env bash
# PermissionRequest and Notification: append one line per event to
# ${CLAUDE_PLUGIN_DATA}/permissions.jsonl for /ogxo-route:stats. It records
# when permission decisions and prompt notifications happen, in which mode,
# and whether a subagent raised them, so the team can see where workers wait
# on prompts. Logs no command text, no message text, and no paths. Outputs
# nothing, so it never changes a permission decision. Never fails the session.
command -v jq >/dev/null 2>&1 || { echo "ogxo-route/permission-log: jq not found; this hook is inactive. Install jq to enable it." >&2; exit 1; }
[ -n "${CLAUDE_PLUGIN_DATA:-}" ] || exit 0
mkdir -p "$CLAUDE_PLUGIN_DATA" 2>/dev/null || exit 0

line=$(jq -c '{
  ts: (now | floor),
  session_id: (.session_id // null),
  event: (.hook_event_name // null),
  tool: (.tool_name // null),
  notification_type: (.notification_type // null),
  mode: (.permission_mode // null),
  nested: ((.agent_id // null) != null),
  agent_type: (.agent_type // null)
}' 2>/dev/null) || exit 0
[ -n "$line" ] || exit 0
printf '%s\n' "$line" >>"$CLAUDE_PLUGIN_DATA/permissions.jsonl" 2>/dev/null
exit 0
