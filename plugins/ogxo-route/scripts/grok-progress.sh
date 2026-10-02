#!/usr/bin/env bash
# Report whether a Grok Build session is making progress, from the event log
# Grok writes for it (~/.grok/sessions/<cwd>/<session id>/events.jsonl).
#   grok-progress.sh <session id> [stall minutes]
# The session id is the thread id that the grok bridge's `runs <job-id>`
# shows. Prints one line: working, idle (its turn ended), or stalled (a turn
# is open and nothing has been written for that many minutes, default 10),
# with the time since the last event and what it was. A tool call still open
# (a long test run) writes no events, so the newest output log of the
# session's commands (terminal/*.log) counts as activity too, and an open
# command with no output for that long is reported apart from a quiet model.
# A turn left open by a process that is gone (stopped, killed, crashed) is
# reported as ended without finishing. Reads only the session's own files and
# the process list.
# Exits 0; the state is in the text.
set -uo pipefail
sid=${1:-}
mins=${2:-10}
[[ $sid =~ ^[A-Za-z0-9_-]{8,128}$ ]] || { echo "usage: grok-progress.sh <session id> [stall minutes]" >&2; exit 2; }
[[ $mins =~ ^[0-9]{1,4}$ ]] || mins=10
root=${GROK_HOME:-${HOME:-}/.grok}/sessions
f=""
for c in "$root"/*/"$sid"/events.jsonl; do [ -f "$c" ] && f=$c && break; done
[ -n "$f" ] || { echo "grok $sid: no session log under $root"; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "grok $sid: jq is required"; exit 0; }

now=$(date +%s)
mtime=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null)
mtime=${mtime//[!0-9]/}
age=$(( now - ${mtime:-$now} ))
# Open turns: started minus ended, counted over the whole log (a long turn
# writes thousands of phase changes). The last event that is not a phase
# change says what it was doing.
started=$(grep -cE '"type": ?"turn_started"' "$f")
ended=$(grep -cE '"type": ?"turn_ended"' "$f")
open=$(( ${started//[!0-9]/} - ${ended//[!0-9]/} ))
tstart=$(grep -cE '"type": ?"tool_started"' "$f")
tdone=$(grep -cE '"type": ?"tool_completed"' "$f")
tools=$(( ${tstart//[!0-9]/} - ${tdone//[!0-9]/} ))
# A running command writes its output under terminal/; count that as activity.
tdir="${f%/events.jsonl}/terminal"
# shellcheck disable=SC2012 # newest by time; the names are Grok call ids
if [ "$tools" -gt 0 ] && [ -d "$tdir" ]; then
  newest=$(ls -t "$tdir" 2>/dev/null | head -1)
  if [ -n "$newest" ]; then
    tm=$(stat -f %m "$tdir/$newest" 2>/dev/null || stat -c %Y "$tdir/$newest" 2>/dev/null)
    tm=${tm//[!0-9]/}
    [ -n "$tm" ] && [ $(( now - tm )) -lt "$age" ] && age=$(( now - tm ))
  fi
fi
last=$(grep -vE '"type": ?"phase_changed"' "$f" | tail -n 1 | jq -r '(.type // "none") + (if .tool_name then ":" + .tool_name else "" end)' 2>/dev/null)
open=${open:-0}
# Is any process still running this session (the bridge's grok -p, or a
# grok -r someone joined with)? Unknown when pgrep is missing.
live=unknown
if command -v pgrep >/dev/null 2>&1; then
  # Match grok's own command line, not any process that mentions the id (on
  # Linux, pgrep -f also matches the shell running this script).
  if pgrep -f -- "grok( [^ ]+)* (--session-id|-r|--resume)[ =]$sid" >/dev/null 2>&1; then live=yes; else live=no; fi
fi
if [ "$open" -gt 0 ] && [ "$live" = no ]; then
  echo "grok $sid: ended without finishing, a turn is open but no process runs this session (stopped, killed, or crashed; last event: ${last:-none}); dispatch it again"
elif [ "$open" -le 0 ]; then
  echo "grok $sid: idle, its turn ended ${age}s ago (last event: ${last:-none}); the run is done or waiting for the next round"
elif [ "$age" -ge $(( mins * 60 )) ] && [ "$tools" -gt 0 ]; then
  echo "grok $sid: quiet, a tool call (${last:-none}) is open with no output for ${age}s; a long test run or build can be this quiet, so check what it runs before stopping it"
elif [ "$age" -ge $(( mins * 60 )) ]; then
  echo "grok $sid: stalled, a turn is open and nothing was written for ${age}s (last event: ${last:-none}); stop the run and dispatch it again"
else
  echo "grok $sid: working, last event ${age}s ago (${last:-none})"
fi
exit 0
