#!/usr/bin/env bash
# Report subagent dispatches logged by the dispatch-log hook.
#   stats.sh [days]   window in days (default 7)
# Drops entries older than 30 days and malformed lines from the log.
set -uo pipefail

command -v jq >/dev/null 2>&1 || { echo "ogxo-route: jq is required" >&2; exit 1; }
days=${1:-7}
[[ "$days" =~ ^[0-9]+$ ]] && [ "$days" -gt 0 ] || { echo "usage: stats [days]" >&2; exit 2; }
file="${CLAUDE_PLUGIN_DATA:-}/dispatches.jsonl"
if [ -z "${CLAUDE_PLUGIN_DATA:-}" ] || [ ! -s "$file" ]; then
  echo "No dispatches recorded yet (log: $file)."
  exit 0
fi

now=$(date +%s)
# Rewrite only when something is dropped: a rewrite replaces the file, and a
# hook appending at that moment would lose its line. The temp file is created
# by redirection so it gets the umask's permissions, like the hook's appends.
tmpf="$CLAUDE_PLUGIN_DATA/dispatches.jsonl.tmp.$$"
trap 'rm -f "$tmpf"' EXIT
jq -R -c --argjson cut $((now - 30 * 86400)) 'fromjson? | objects | select((.ts | type) == "number" and .ts >= $cut)' "$file" >"$tmpf" 2>/dev/null || exit 1
kept=$(wc -l <"$tmpf")
total=$(wc -l <"$file")
if [ "$kept" -ne "$total" ]; then
  mv "$tmpf" "$file"
fi

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
