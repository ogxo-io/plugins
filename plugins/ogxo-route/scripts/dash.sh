#!/usr/bin/env bash
# Control the live route board for a Claude Code session.
#   dash.sh [on] [session_id]   start recording; copy the page; print its URL
#   dash.sh off [session_id]    stop recording (board files kept for replay)
#   dash.sh status [session_id] show on/off and the board path
#   dash.sh batch [session_id]  record a batch table (JSON array on stdin)
#   dash.sh hub                 print the URL of the page listing every board
#   dash.sh demo                print the URL of the page's built-in replay
# session_id defaults to $CLAUDE_CODE_SESSION_ID. Board: the page, events.js
# (appended by hooks/dash-event.sh while the `on` flag exists), meta.json and
# the flag, in ${CLAUDE_PLUGIN_DATA}/dash/<session_id>/. The hub is
# dash/index.html; it reads dash/boards.js, rewritten here on on/off/hub.
set -uo pipefail

usage() { echo "usage: dashboard [on|off|status|batch|hub|demo] [session_id]" >&2; exit 2; }

command -v jq >/dev/null 2>&1 || { echo "ogxo-route: jq is required" >&2; exit 1; }
data=${CLAUDE_PLUGIN_DATA:-}
[ -n "$data" ] || { echo "ogxo-route: CLAUDE_PLUGIN_DATA is not set" >&2; exit 1; }
case $data in /*) ;; *) data="$PWD/$data" ;; esac

[ $# -le 2 ] || usage
action=${1:-on}
case $action in on | off | status | batch | hub | demo) ;; *) usage ;; esac

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd) || exit 1
if [ "$action" = demo ]; then
  echo "Open: file://${root// /%20}/dashboard/index.html?demo"
  exit 0
fi

re='^[A-Za-z0-9_-]{1,128}$'
base="$data/dash"

# registry: rewrite boards.js, one `B({...});` per board, for the hub. It is
# small and only written here, so a temp file and mv keep readers whole.
registry() {
  local tmp="$base/boards.js.tmp.$$" d name on
  : >"$tmp" || return 1
  for d in "$base"/*; do
    name=${d##*/}
    [[ $name =~ $re ]] || continue
    if [ ! -d "$d" ] || [ -L "$d" ]; then continue; fi
    if [ -e "$d/on" ]; then on=true; else on=false; fi
    { jq -c --arg sid "$name" --argjson on "$on" \
        '{sid: $sid, repo: (.repo // ""), branch: (.branch // ""), wt: (.wt // ""), cwd: (.cwd // ""), on: $on}' \
        "$d/meta.json" 2>/dev/null ||
      jq -nc --arg sid "$name" --argjson on "$on" '{sid: $sid, on: $on}'; } |
      sed 's/^/B(/; s/$/);/' >>"$tmp"
  done
  mv "$tmp" "$base/boards.js"
}
hub() {
  mkdir -p "$base" && cp "$root/dashboard/hub.html" "$base/index.html" && registry
}

if [ "$action" = hub ]; then
  hub || exit 1
  echo "Open: file://${base// /%20}/index.html"
  exit 0
fi

sid=${2:-${CLAUDE_CODE_SESSION_ID:-}}
[ -n "$sid" ] || { echo "ogxo-route: no session id (CLAUDE_CODE_SESSION_ID is not set)" >&2; usage; }
[[ $sid =~ $re ]] || { echo "ogxo-route: invalid session id" >&2; usage; }
dir="$base/$sid"
url="file://${dir// /%20}/index.html"

# append <json>: one write per event; events.js is only ever appended to.
append() { printf 'E(%s);\n' "$1" >>"$dir/events.js"; }

case $action in
  on)
    mkdir -p "$dir" || exit 1
    cp "$root/dashboard/index.html" "$dir/index.html" || exit 1
    : >"$dir/on" || exit 1
    top=$(git rev-parse --show-toplevel 2>/dev/null) || top=""
    repo=$(basename "${top:-$PWD}")
    branch=$(git branch --show-current 2>/dev/null) || branch=""
    # In a linked worktree the common git dir is not <toplevel>/.git: name the
    # board after the main repository and record the worktree's folder.
    wt=""
    common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || common=""
    if [ -n "$top" ] && [ -n "$common" ] && [ "$common" != "$top/.git" ]; then
      wt=$repo
      repo=$(basename "$(dirname "$common")")
    fi
    ev=$(jq -nc --arg sid "$sid" --arg repo "$repo" --arg branch "$branch" --arg wt "$wt" \
      '{t: (now * 1000 | floor), e: "on", sid: $sid, repo: $repo, branch: $branch, wt: $wt}') || exit 1
    append "$ev" || exit 1
    cwd=${PWD/#"$HOME"/\~}
    jq -nc --arg repo "$repo" --arg branch "$branch" --arg wt "$wt" --arg cwd "$cwd" \
      '{repo: $repo, branch: $branch, wt: $wt, cwd: $cwd}' >"$dir/meta.json" || exit 1
    # Prune other sessions' boards that are off and untouched for 7 days.
    for d in "$base"/*; do
      name=${d##*/}
      [[ $name =~ $re ]] || continue
      if [ ! -d "$d" ] || [ -L "$d" ] || [ "$name" = "$sid" ] || [ -e "$d/on" ]; then continue; fi
      ref=$d
      [ -f "$d/events.js" ] && ref="$d/events.js"
      [ -n "$(find "$ref" -maxdepth 0 -mmin +10080 2>/dev/null)" ] || continue
      rm -rf "$d"
    done
    hub || exit 1
    echo "Route board on for session ${sid:0:8}."
    echo "Open: $url"
    echo "It updates live as this session works; /ogxo-route:dashboard off stops recording, /ogxo-route:dashboard hub lists every board."
    ;;
  off)
    rm -f "$dir/on"
    [ -d "$base" ] && registry
    echo "Route board off for session ${sid:0:8}; the board files stay at $dir for replay."
    ;;
  status)
    if [ -e "$dir/on" ]; then state=on; else state=off; fi
    echo "Route board: $state (session ${sid:0:8})"
    echo "Path: $dir/index.html"
    ;;
  batch)
    rows=$(jq -cs 'if length == 1 and (.[0] | type) == "array" and (.[0] | all(type == "object"))
      then .[0] else error("not an array of objects") end' 2>/dev/null) || {
      echo "ogxo-route: batch expects a JSON array of objects on stdin" >&2
      exit 2
    }
    if [ ! -e "$dir/on" ]; then
      echo "Route board is off for session ${sid:0:8}; batch not recorded."
      exit 0
    fi
    ev=$(jq -nc --argjson rows "$rows" '{t: (now * 1000 | floor), e: "batch", rows: $rows}') || exit 1
    append "$ev" || exit 1
    ;;
esac
