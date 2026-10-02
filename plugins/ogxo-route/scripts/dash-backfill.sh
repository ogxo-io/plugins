#!/usr/bin/env bash
# Add the workers a session ran before its board was turned on (or while it
# was off) to the board. dash.sh runs this in the background on `on`.
#   dash-backfill.sh <board dir> <session_id>
# Claude Code keeps each worker's transcript in
# <projects>/<project>/<session_id>/subagents/agent-<id>.jsonl, with its type
# and description in agent-<id>.meta.json. For each worker not on the board
# yet, appends an sstart and an sstop event at the transcript's first and
# last timestamps (bf: true), with its model, tool count, token usage and verdict, and records
# "<id> <bytes read> <last message id>" in bf.ids so the worker's own
# SubagentStop, when it is still running, counts only what came after.
# Reads local files only; prints nothing; exits 0.
set -uo pipefail
dir=${1:-}
sid=${2:-}
re='^[A-Za-z0-9_-]{1,128}$'
[ -n "$dir" ] && [ -d "$dir" ] && [[ $sid =~ $re ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
# shellcheck source=SCRIPTDIR/../hooks/jqdefs.sh
. "${BASH_SOURCE[0]%/*}/../hooks/jqdefs.sh"

projects=${CLAUDE_CONFIG_DIR:-${HOME:-}/.claude}/projects
[ -d "$projects" ] || exit 0
# One run at a time per board: `on` twice in a row must not add workers twice.
lock="$dir/bf.lock"
mkdir "$lock" 2>/dev/null || exit 0
new="$lock/events"
trap 'rm -f "$new"; rmdir "$lock" 2>/dev/null' EXIT
: >"$new" || exit 0

for f in "$projects"/*/"$sid"/subagents/agent-*.jsonl; do
  [ -f "$f" ] || continue
  id=${f##*/agent-}
  id=${id%.jsonl}
  [[ $id =~ $re ]] || continue
  # Already on the board, from a hook while it was on or an earlier backfill.
  grep -qF "\"id\":\"$id\"" "$dir/events.js" 2>/dev/null && continue
  grep -q "^$id " "$dir/bf.ids" 2>/dev/null && continue
  meta=${f%.jsonl}.meta.json
  ty=$(jq -r '.agentType // empty | strings' "$meta" 2>/dev/null)
  # The page skips workers with no type (Claude Code's own helpers).
  [ -n "$ty" ] || continue
  d=$(jq -r '.description // empty | strings' "$meta" 2>/dev/null)
  size=$(wc -c <"$f" 2>/dev/null)
  size=${size//[!0-9]/}
  if [ -z "$size" ] || [ "$size" -eq 0 ] || [ "$size" -ge 52428800 ]; then continue; fi
  # Complete lines only: a line still being written is left to SubagentStop.
  used=$size
  if [ -n "$(tail -c 1 "$f")" ]; then
    part=$(tail -n 1 "$f" | wc -c)
    used=$((used - ${part//[!0-9]/}))
  fi
  [ "$used" -gt 0 ] || continue
  evs=$(head -c "$used" "$f" | jq -R -n -c --arg id "$id" --arg ty "$ty" --arg d "${d:0:120}" "$vdef $udef"'
    def ms: if type == "string" then (sub("\\.[0-9]+"; "") | fromdateiso8601? // null | if . then . * 1000 else null end) else null end;
    reduce (inputs | fromjson? | objects) as $l
      ({t0: null, t1: null, ids: {}, anon: 0, txt: null, msgs: {}, last: null, model: null, tc: 0, seq: []};
       ($l.timestamp | ms) as $t
       | (if $t then .t0 = (.t0 // $t) | .t1 = $t else . end)
       | if $l.type == "assistant" and ($l.message | type) == "object" then
           $l.message as $m
           | (($m.usage | if type == "object" then .output_tokens else null end) | if type == "number" then . else 0 end) as $n
           | (if ($m.model | type) == "string" and ($m.model | startswith("<") | not) then .model = $m.model else . end)
           | (if ($m.id | type) == "string" then (if .ids | has($m.id) then . else .seq += [$m.id] end) | .ids[$m.id] = ([.ids[$m.id] // 0, $n] | max) | .msgs[$m.id] = {model: $m.model, usage: $m.usage} | .last = $m.id else .anon += $n end)
           | .tc += ([$m.content[]? | objects | select(.type == "tool_use")] | length)
           | ([$m.content[]? | objects | select(.type == "text") | .text | strings] | join("\n")) as $x
           | if $x != "" then .txt = $x else . end
         else . end)
    | select(.t0 != null)
    | {t: .t0, e: "sstart", id: $id, ty: $ty, d: $d, rm: .model, bf: true},
      {t: .t1, e: "sstop", id: $id, ty: $ty, v: (.txt | verdict), out: (.anon + ([.ids[]] | add // 0)), tc: .tc,
       use: ([.msgs[] | rows] | bucket), bf: true} + (. as $s | [$s.seq[] | $s.msgs[.]] | ctxinfo(true)),
      {last: (.last // "")}' 2>/dev/null)
  [ -n "$evs" ] || continue
  last=$(tail -n 1 <<<"$evs" | jq -r '.last // empty' 2>/dev/null)
  [[ $last =~ $re ]] || last=""
  # bf.ids first: a SubagentStop from now on counts only what comes after.
  printf '%s %s %s\n' "$id" "$used" "$last" >>"$dir/bf.ids" 2>/dev/null || continue
  sed '$d' <<<"$evs" >>"$new"
done
# In time order, so the page's log reads in order.
[ -s "$new" ] || exit 0
jq -s -c 'sort_by(.t) | .[]' "$new" 2>/dev/null | sed -e 's/^/E(/' -e 's/$/);/' >>"$dir/events.js"
exit 0
