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

line=$(jq -n -R -c --arg s "$session" '
  reduce (inputs | fromjson? | objects | select(.type == "assistant")) as $m
    ({n: 0, ids: []};
     .n += 1
     | .ids += [$m.message.content? | arrays | .[] | objects
                | select(.type == "server_tool_use" and .name == "advisor") | .id])
  | {ts: (now | floor),
     session_id: (if $s == "" then null else $s end),
     advisor_calls: (.ids | unique | length),
     assistant_entries: .n}' "$transcript" 2>/dev/null) || exit 0
[ -n "$line" ] || exit 0
printf '%s\n' "$line" >>"$CLAUDE_PLUGIN_DATA/advisor.jsonl" 2>/dev/null
exit 0
