#!/usr/bin/env bash
# SessionStart: print the routing summary and any unexpired "off" markers for
# external agents. Claude Code only: the same hooks.json runs under Grok
# Build, where this must print nothing.
[ "${CLAUDECODE:-}" = "1" ] || exit 0
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || exit 0

cat "$CLAUDE_PLUGIN_ROOT/hooks/anchor.md" 2>/dev/null || exit 0

f="${CLAUDE_PLUGIN_DATA:-}/external.json"
[ -n "${CLAUDE_PLUGIN_DATA:-}" ] && [ -f "$f" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

now=$(date +%s)
jq -r --argjson now "$now" '
  to_entries[]
  | select((.value.off_until | type) == "number" and .value.off_until > $now)
  | "- \(.key) is marked off until \(.value.off_until | strftime("%Y-%m-%d %H:%M UTC")): route its work to native workers unless the user names it (/ogxo-route:external on \(.key) to clear)."
' "$f" 2>/dev/null
exit 0
