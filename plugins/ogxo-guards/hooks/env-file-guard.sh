#!/usr/bin/env bash
# PreToolUse (Bash): exit 2 when a `git add` / `git stage` would stage a
# sensitive file. Checks the pathspecs given to add/stage, not the rest of
# the command, and for broad adds (-A, -u, ., a directory, a glob) asks
# `git status` which paths they would pick up. The hooks.json entry checks
# for jq before running this script.

input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
[ -n "$cmd" ] || exit 0
base=$(jq -r '.cwd // empty' <<<"$input")
[ -n "$base" ] || base=$PWD

# Default names, matched against a path's last component.
default_re='^\.env(\..+)?$|\.(pem|key|p12|pfx)$|^id_(rsa|dsa|ecdsa|ed25519)$|credentials|\.secret'
template_re='^\.env\.(example|sample|template|dist)$'

sensitive() {
  local path=$1 name extra line
  name=${path##*/}
  if grep -qE "$default_re" <<<"$name" && ! grep -qE "$template_re" <<<"$name"; then
    return 0
  fi
  # Per-repository additions: .claude/ogxo-guards-sensitive, one ERE per
  # line matched against the path, # for comments.
  extra="$root/.claude/ogxo-guards-sensitive"
  if [ -n "$root" ] && [ -f "$extra" ]; then
    while IFS= read -r line; do
      case "$line" in '' | '#'*) continue ;; esac
      grep -qE -- "$line" <<<"$path" && return 0
    done <"$extra"
  fi
  return 1
}

block() {
  echo "BLOCKED: git add would stage a sensitive file ($1). Review and stage it manually if intended, or add it to .gitignore." >&2
  exit 2
}

# Split into command segments at shell separators, then look at each one.
segments=$(printf '%s\n' "$cmd" | tr ';&|()\n' '\n\n\n\n\n\n')
while IFS= read -r seg; do
  read -r -a words <<<"$seg" || continue
  i=0
  n=${#words[@]}
  # Skip leading env assignments and find `git`.
  while [ "$i" -lt "$n" ] && [[ "${words[$i]}" == *=* ]]; do i=$((i + 1)); done
  [ "$i" -lt "$n" ] && [ "${words[$i]}" = git ] || continue
  i=$((i + 1))
  dir=$base
  # git's global options before the subcommand.
  while [ "$i" -lt "$n" ]; do
    case "${words[$i]}" in
      -C)
        d=${words[$((i + 1))]:-}
        d=${d//\"/}
        d=${d//\'/}
        case "$d" in /*) dir=$d ;; *) dir=$base/$d ;; esac
        i=$((i + 2))
        ;;
      -c) i=$((i + 2)) ;;
      -*) i=$((i + 1)) ;;
      *) break ;;
    esac
  done
  case "${words[$i]:-}" in add | stage) ;; *) continue ;; esac
  i=$((i + 1))

  root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)
  broad=0
  update_only=0
  specs=()
  after_dashes=0
  while [ "$i" -lt "$n" ]; do
    w=${words[$i]//\"/}
    w=${w//\'/}
    i=$((i + 1))
    case "$w" in '#'*) break ;; esac
    if [ "$after_dashes" -eq 0 ]; then
      case "$w" in
        --) after_dashes=1; continue ;;
        -A | --all | --no-ignore-removal) broad=1; continue ;;
        -u | --update) broad=1; update_only=1; continue ;;
        -*) continue ;;
      esac
    fi
    specs+=("$w")
    sensitive "$w" && block "$w"
    case "$w" in *'*'* | *'?'* | *'['*) broad=1 ;; esac
    case "$w" in /*) [ -d "$w" ] && broad=1 ;; *) [ -d "$dir/$w" ] && broad=1 ;; esac
  done
  [ "${#specs[@]}" -eq 0 ] && [ "$broad" -eq 0 ] && continue

  # Broad add: list what git would consider, within the given pathspecs.
  [ "$broad" -eq 1 ] && [ -n "$root" ] || continue
  status=$(git -C "$dir" status --porcelain --untracked-files=all -- "${specs[@]}" 2>/dev/null)
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    code=${entry:0:2}
    path=${entry:3}
    path=${path##* -> }
    path=${path//\"/}
    [ "$update_only" -eq 1 ] && [ "$code" = '??' ] && continue
    sensitive "$path" && block "$path"
  done <<<"$status"
done <<<"$segments"
exit 0
