#!/usr/bin/env bash
# Mark an external agent (grok, codex) off for routing, or back on.
#   external.sh                     show status
#   external.sh off <name> [hours]  off for <hours> (default 24)
#   external.sh on <name>           clear the marker
# State: ${CLAUDE_PLUGIN_DATA}/external.json, {"<name>": {"off_until": <epoch>}}.
set -uo pipefail

usage() { echo "usage: external [status] | on <grok|codex> | off <grok|codex> [hours]" >&2; exit 2; }

command -v jq >/dev/null 2>&1 || { echo "ogxo-route: jq is required" >&2; exit 1; }
dir=${CLAUDE_PLUGIN_DATA:-}
[ -n "$dir" ] || { echo "ogxo-route: CLAUDE_PLUGIN_DATA is not set" >&2; exit 1; }
mkdir -p "$dir" || exit 1
file="$dir/external.json"
if ! jq -e 'type == "object"' "$file" >/dev/null 2>&1; then
  [ -f "$file" ] && echo "ogxo-route: $file was not valid JSON; starting fresh" >&2
  echo '{}' >"$file"
fi

action=${1:-status}
name=${2:-}
hours=${3:-24}
now=$(date +%s)

case "$action" in
  status)
    echo "State: $file"
    for n in grok codex; do
      jq -r --arg n "$n" --argjson now "$now" '
        if ((.[$n].off_until | numbers) // 0) > $now
        then "\($n): off until \(.[$n].off_until | strftime("%Y-%m-%d %H:%M UTC"))"
        else "\($n): on" end' "$file"
    done
    ;;
  on | off)
    case "$name" in grok | codex) ;; *) usage ;; esac
    [[ "$hours" =~ ^[0-9]+$ ]] && [ "$hours" -gt 0 ] || usage
    # Created by redirection so it gets the umask's permissions.
    tmpf="$file.tmp.$$"
    trap 'rm -f "$tmpf"' EXIT
    if [ "$action" = off ]; then
      jq --arg n "$name" --argjson u $((now + hours * 3600)) '.[$n] = {off_until: $u}' "$file" >"$tmpf"
      echo "$name marked off for ${hours}h; routing uses native workers for it."
    else
      jq --arg n "$name" 'del(.[$n])' "$file" >"$tmpf"
      echo "$name marked on."
    fi
    mv "$tmpf" "$file"
    ;;
  *) usage ;;
esac
