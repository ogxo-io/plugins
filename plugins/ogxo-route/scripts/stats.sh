#!/usr/bin/env bash
# Report subagent dispatches logged by the dispatch-log hook.
#   stats.sh [days]   window in days (default 7)
# Drops entries older than 30 days and malformed lines from the log.
set -uo pipefail

command -v jq >/dev/null 2>&1 || { echo "ogxo-route: jq is required" >&2; exit 1; }
days=${1:-7}
[[ "$days" =~ ^[0-9]+$ ]] && [ "$days" -gt 0 ] || { echo "usage: stats [days]" >&2; exit 2; }
file="${CLAUDE_PLUGIN_DATA:-}/dispatches.jsonl"
perms="${CLAUDE_PLUGIN_DATA:-}/permissions.jsonl"
now=$(date +%s)
trap 'rm -f "$file.tmp.$$" "$perms.tmp.$$"' EXIT

# prune <log>: drop entries older than 30 days and malformed lines. Rewrites
# only when something is dropped: a rewrite replaces the file, and a hook
# appending at that moment would lose its line. The temp file is created by
# redirection so it gets the umask's permissions, like the hooks' appends.
prune() {
  local log=$1 tmpf kept total
  tmpf="$log.tmp.$$"
  jq -R -c --argjson cut $((now - 30 * 86400)) 'fromjson? | objects | select((.ts | type) == "number" and .ts >= $cut)' "$log" >"$tmpf" 2>/dev/null || { rm -f "$tmpf"; return 1; }
  kept=$(wc -l <"$tmpf")
  total=$(wc -l <"$log")
  if [ "$kept" -ne "$total" ]; then
    mv "$tmpf" "$log"
  else
    rm -f "$tmpf"
  fi
}

# permission_report: permission requests and prompt notifications, if any.
permission_report() {
  [ -n "${CLAUDE_PLUGIN_DATA:-}" ] && [ -s "$perms" ] || return 0
  prune "$perms" || return 0
  echo ""
  jq -s -r --argjson cut $((now - days * 86400)) --argjson days "$days" '
    map(select(.ts >= $cut)) as $d
    | ($d | map(select(.event == "PermissionRequest"))) as $r
    | ($d | map(select(.event == "Notification"))) as $n
    | "Permission requests in the last \($days) days: \($r | length) (\($r | map(select(.nested)) | length) from inside subagents)",
    ($r | group_by([(.mode // "?"), .nested])
        | map({c: length, k: "\(.[0].mode // "?")  \(if .[0].nested then "subagent" else "main session" end)"})
        | sort_by(-.c)[] | "  \(.c)\t\(.k)"),
    "Prompt notifications: \($n | length) (\($n | map(select(.nested)) | length) from inside subagents)",
    ($n | group_by(.notification_type // "?")
        | map({c: length, k: (.[0].notification_type // "?")})
        | sort_by(-.c)[] | "  \(.c)\t\(.k)")
  ' "$perms"
  echo ""
  echo "Permission log: $perms"
}

if [ -z "${CLAUDE_PLUGIN_DATA:-}" ] || [ ! -s "$file" ]; then
  echo "No dispatches recorded yet (log: $file)."
  permission_report
  exit 0
fi

prune "$file" || exit 1

jq -s -r --argjson cut $((now - days * 86400)) --argjson days "$days" '
  def lbl: if .subagent_type == "" then "(none)" else .subagent_type end;
  map(select(.ts >= $cut)) as $d
  | "Dispatches in the last \($days) days: \($d | length) (\($d | map(select(.nested)) | length) from inside subagents)",
  "",
  "By agent and requested model (\"pin/inherit\" = no model passed):",
  ($d | group_by([lbl, (.requested_model // "pin/inherit")])
      | map({n: length, k: "\(.[0] | lbl)  \(.[0].requested_model // "pin/inherit")"})
      | sort_by(-.n)[] | "  \(.n)\t\(.k)"),
  "",
  "Generic dispatches with no model: \($d | map(select(.subagent_type as $t | (["", "general-purpose", "Explore", "Plan"] | any(. == $t)) and .requested_model == null)) | length)"
' "$file"
echo ""
echo "Log: $file"
permission_report
