#!/usr/bin/env bash
# SessionEnd and PreCompact: count the main session's advisor calls and append
# {ts, session_id, advisor_calls, assistant_entries} to
# ${CLAUDE_PLUGIN_DATA}/advisor.jsonl for /ogxo-route:stats. The advisor runs
# on the API side (a server_tool_use block named advisor in the transcript),
# so no PreToolUse or PostToolUse hook sees it; this reads the transcript at
# transcript_path instead. That format is Claude Code's own and undocumented:
# assistant_entries lets stats tell "no advisor calls" from "transcript not
# recognised". Only the main session's transcript is read; a subagent's
# advisor calls, if any, are in a separate file and not counted. A session can
# log several lines (each compaction, then the end); stats keeps the latest.
# Logs counts only: no text and no paths. Prints nothing. Never fails the
# session and never blocks compaction.
command -v jq >/dev/null 2>&1 || { echo "ogxo-route/advisor-count: jq not found; this hook is inactive. Install jq to enable it." >&2; exit 1; }
[ -n "${CLAUDE_PLUGIN_DATA:-}" ] || exit 0

input=$(cat)
transcript=$(jq -r '.transcript_path // empty' <<<"$input" 2>/dev/null)
[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0
session=$(jq -r '.session_id // empty' <<<"$input" 2>/dev/null)
mkdir -p "$CLAUDE_PLUGIN_DATA" 2>/dev/null || exit 0

# grep first: jq parsing every line of a long transcript is far slower. Even
# so, a 750 MB transcript takes about 8 s with macOS's grep, past the 1.5 s
# SessionEnd default, so hooks.json gives this hook a 30 s timeout.
# assistant_entries is the number of lines naming an assistant entry; if the
# format changes it drops to 0 and stats reports the transcript as not
# recognised.
entries=$(LC_ALL=C grep -c '"type":"assistant"' "$transcript" 2>/dev/null)
entries=${entries//[!0-9]/}
calls=$(LC_ALL=C grep -F '"server_tool_use"' "$transcript" 2>/dev/null | jq -R -r '
  fromjson? | objects | select(.type == "assistant")
  | .message.content? | arrays | .[] | objects
  | select(.type == "server_tool_use" and .name == "advisor") | .id | strings' 2>/dev/null | sort -u | wc -l)
calls=${calls//[!0-9]/}
line=$(jq -n -c --arg s "$session" --argjson c "${calls:-0}" --argjson n "${entries:-0}" \
  '{ts: (now | floor), session_id: (if $s == "" then null else $s end), advisor_calls: $c, assistant_entries: $n}' 2>/dev/null) || exit 0
[ -n "$line" ] || exit 0
printf '%s\n' "$line" >>"$CLAUDE_PLUGIN_DATA/advisor.jsonl" 2>/dev/null
exit 0
