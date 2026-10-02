#!/usr/bin/env bash
# Keep a session handoff note outside the repository, one per repository and
# branch, so a fresh or compacted session can continue without carrying the
# old conversation. The note itself is written by the model (see
# commands/handoff.md); this script only decides where it lives and stores it.
#   handoff.sh path     print where this repository and branch keep their note
#   handoff.sh write    store stdin as that note (the old one becomes <name>.prev)
#   handoff.sh show     print the note, or say there is none and list the others
#   handoff.sh latest   print the path of the newest note for this repository
#   handoff.sh facts    print the git state a note should be written from
# Notes are in ${OGXO_ROUTE_HANDOFF:-$HOME/.ogxo/route/handoff}/<repository>/
# <branch>.md, readable by you only. A linked worktree files under the main
# repository's name. Prints what happened and exits 0.
# shellcheck disable=SC2012 # ls -t orders by time; names are the script's own
set -uo pipefail
umask 077

usage() { echo "usage: handoff.sh path|write|show|latest|facts" >&2; exit 2; }
action=${1:-}
case $action in path | write | show | latest | facts) ;; *) usage ;; esac

base=${OGXO_ROUTE_HANDOFF:-}
if [ -z "$base" ]; then
  [ -n "${HOME:-}" ] || { echo "ogxo-route: set OGXO_ROUTE_HANDOFF or HOME" >&2; exit 1; }
  base="$HOME/.ogxo/route/handoff"
fi
base=${base%/}

slug() {
  local s
  s=$(printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '-' | sed -e 's/^[-.]*//' -e 's/-*$//')
  printf '%s' "${s:0:80}"
}

# The main repository's name, also from inside a linked worktree.
repo=""
common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || common=""
if [ -n "$common" ]; then
  case $common in */.git) repo=$(basename "$(dirname "$common")") ;; *) repo=$(basename "$common") ;; esac
fi
[ -n "$repo" ] || repo=$(basename "$PWD")
repo=$(slug "$repo")
[ -n "$repo" ] || repo=session
branch=$(git branch --show-current 2>/dev/null) || branch=""
branch=$(slug "$branch")
[ -n "$branch" ] || branch=detached
dir="$base/$repo"
file="$dir/$branch.md"

case $action in
  path) echo "$file" ;;
  write)
    mkdir -p "$dir" || { echo "ogxo-route: cannot create $dir" >&2; exit 1; }
    tmp=$(mktemp "$dir/.new.XXXXXX") || exit 1
    cat >"$tmp"
    if [ ! -s "$tmp" ]; then
      rm -f "$tmp"
      echo "handoff: nothing to write (the note was empty)"
      exit 0
    fi
    [ ! -f "$file" ] || mv "$file" "$file.prev"
    mv "$tmp" "$file"
    bytes=$(wc -c <"$file" | tr -d ' ')
    echo "handoff written: $file ($bytes bytes)"
    [ "$bytes" -le 8000 ] || echo "handoff: long for a handoff; the next session reads all of it on every message, so trim it to what is needed"
    ;;
  show)
    if [ -f "$file" ]; then
      echo "handoff: $file"
      cat "$file"
    else
      echo "handoff: no note for $repo on $branch"
      newest=$(ls -t "$dir"/*.md 2>/dev/null | head -5)
      [ -z "$newest" ] || { echo "other notes for $repo (newest first):"; echo "$newest"; }
    fi
    ;;
  latest)
    newest=$(ls -t "$dir"/*.md 2>/dev/null | head -1)
    [ -z "$newest" ] || echo "$newest"
    ;;
  facts)
    echo "branch: ${branch}  repository: ${repo}  directory: $PWD"
    echo "--- status"; git status --short 2>&1 | head -40
    echo "--- recent commits"; git log --oneline -5 2>&1
    echo "--- worktrees"; git worktree list 2>&1
    echo "--- note file"; echo "$file"
    ;;
esac
exit 0
