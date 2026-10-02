#!/usr/bin/env bash
# Report whether a Grok Build session is making progress, from the event log
# Grok writes for it (~/.grok/sessions/<cwd>/<session id>/events.jsonl).
#   grok-progress.sh <session id> [stall minutes]
#   grok-progress.sh [--all]    every grok process running now, one block each
# The session id is the one the grok bridge's `runs <job-id>` shows ("Grok
# session ID"). Prints one line: working, idle (its turn ended), quiet (a tool
# call is open with no output for that many minutes, default 10, such as a
# long test run), stalled (a turn is open and nothing has been written for
# that long), or ended without finishing (a turn is open but no grok process
# has the session open: stopped, killed, or crashed), with the time since the
# last event and what it was. A running command writes no events, so the
# newest output log of the session's commands (terminal/*.log) counts as
# activity. Reads only the session's own files and the process list.
# Exits 0; the state is in the text.
set -uo pipefail
root=${GROK_HOME:-${HOME:-}/.grok}/sessions
re='^[A-Za-z0-9_-]{8,128}$'

# mtime <file>: modification time in seconds (macOS, then GNU stat).
mtime() { local m; m=$(stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null); printf '%s' "${m//[!0-9]/}"; }

# report <session id> <stall minutes>: the one-line state.
report() {
  local sid=$1 mins=$2 f="" c now age started ended open tstart tdone tools tdir newest tm last live
  for c in "$root"/*/"$sid"/events.jsonl; do [ -f "$c" ] && f=$c && break; done
  [ -n "$f" ] || { echo "grok $sid: no session log under $root"; return 0; }
  now=$(date +%s)
  age=$(mtime "$f")
  age=$(( now - ${age:-$now} ))
  # Open turns and tool calls: started minus ended, counted over the whole
  # log (a long turn writes thousands of phase changes).
  started=$(grep -cE '"type": ?"turn_started"' "$f")
  ended=$(grep -cE '"type": ?"turn_ended"' "$f")
  open=$(( ${started//[!0-9]/} - ${ended//[!0-9]/} ))
  tstart=$(grep -cE '"type": ?"tool_started"' "$f")
  tdone=$(grep -cE '"type": ?"tool_completed"' "$f")
  tools=$(( ${tstart//[!0-9]/} - ${tdone//[!0-9]/} ))
  tdir="${f%/events.jsonl}/terminal"
  if [ "$tools" -gt 0 ] && [ -d "$tdir" ]; then
    # shellcheck disable=SC2012 # newest by time; the names are Grok call ids
    newest=$(ls -t "$tdir" 2>/dev/null | head -1)
    if [ -n "$newest" ]; then
      tm=$(mtime "$tdir/$newest")
      [ -n "$tm" ] && [ $(( now - tm )) -lt "$age" ] && age=$(( now - tm ))
    fi
  fi
  # The last event that is not a phase change says what it was doing.
  last=$(grep -vE '"type": ?"phase_changed"' "$f" | tail -n 1 | jq -r '(.type // "none") + (if .tool_name then ":" + .tool_name else "" end)' 2>/dev/null)
  # Is a grok process running this session (the bridge's grok -p, or a grok
  # -r someone joined with)? Match grok's own command line: on Linux, pgrep -f
  # also matches the shell running this script, whose arguments hold the id.
  live=unknown
  if command -v pgrep >/dev/null 2>&1; then
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
}

command -v jq >/dev/null 2>&1 || { echo "grok: jq is required"; exit 0; }

if [ $# -eq 0 ] || [ "${1:-}" = --all ]; then
  # Every grok process with a session on its command line: the bridge runs
  # grok --session-id <id> -p <brief>; a joined terminal runs grok -r <id>.
  n=0
  seen=" "
  while IFS= read -r line; do
    pid=${line%% *}
    args=${line#* }
    # The program itself must be grok, not a shell or editor whose arguments
    # mention it.
    prog=${args%% *}
    [ "${prog##*/}" = grok ] || continue
    [[ $args =~ \ (--session-id|-r|--resume)[\ =]([A-Za-z0-9_-]{8,128}) ]] || continue
    sid=${BASH_REMATCH[2]}
    case $seen in *" $sid "*) continue ;; esac
    seen="$seen$sid "
    n=$((n + 1))
    how=joined
    [[ $args =~ --session-id ]] && how=bridge
    brief=""
    [[ $args =~ \ -p\ (.*)$ ]] && brief=${BASH_REMATCH[1]}
    brief=${brief%% --*}
    brief=$(printf '%s' "$brief" | tr -s '[:space:]' ' ' | cut -c1-90)
    dir=""
    for c in "$root"/*/"$sid"; do
      [ -d "$c" ] || continue
      dir=${c%/"$sid"}
      dir=${dir##*/}
      dir=${dir//%2F//}
      break
    done
    report "$sid" 10
    echo "  pid $pid ($how)${dir:+  in $dir}"
    [ -z "$brief" ] || echo "  brief: $brief"
  # ps prints full command lines on macOS and Linux alike (pgrep -l does not).
  done < <(ps -axo pid=,args= 2>/dev/null | sed 's/^ *//')
  [ "$n" -gt 0 ] || echo "grok: no grok session is running"
  exit 0
fi

sid=$1
mins=${2:-10}
[[ $sid =~ $re ]] || { echo "usage: grok-progress.sh <session id> [stall minutes] | grok-progress.sh [--all]" >&2; exit 2; }
[[ $mins =~ ^[0-9]{1,4}$ ]] || mins=10
report "$sid" "$mins"
exit 0
