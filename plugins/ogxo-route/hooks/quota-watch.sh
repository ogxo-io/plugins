#!/usr/bin/env bash
# PostToolUse (Agent|Task|Bash): when a grok run (the grok-build:grok-delegate
# agent, or a Bash call to grok-bridge.mjs) fails because the Grok Build
# balance is exhausted (HTTP 402), mark grok off for routing for 24h and tell
# Claude. Rate limits (429) are left alone: they pass in minutes. The marker
# affects routing only; a grok run the user names still goes to grok.
command -v jq >/dev/null 2>&1 || { echo "ogxo-route/quota-watch: jq not found; this hook is inactive. Install jq to enable it." >&2; exit 1; }
[ -n "${CLAUDE_PLUGIN_DATA:-}" ] && [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || exit 0

hit=$(jq -r '
  (((.tool_input.subagent_type // "") == "grok-build:grok-delegate")
    or ((.tool_input.command // "") | test("grok-bridge\\.mjs")))
  and ((.tool_response // "" | tostring)
    | test("http_status[^0-9]{0,6}402|usage balance exhausted"; "i"))
' 2>/dev/null)
[ "$hit" = true ] || exit 0

CLAUDE_PLUGIN_DATA="$CLAUDE_PLUGIN_DATA" bash "$CLAUDE_PLUGIN_ROOT/scripts/external.sh" off grok 24 >/dev/null 2>&1 || exit 0

jq -nc '{hookSpecificOutput: {
  hookEventName: "PostToolUse",
  additionalContext: "ogxo-route: grok reported its usage balance is exhausted (HTTP 402) and is now marked off for routing for 24h. If routing chose grok for this task, re-dispatch it natively (ogxo-route:implementer at the same class, after restoring any files grok touched). If the user asked for grok by name, report the failure, point to /grok-build:check, and do not substitute. Clear the marker with /ogxo-route:external on grok once the balance is topped up."
}}'
exit 0
