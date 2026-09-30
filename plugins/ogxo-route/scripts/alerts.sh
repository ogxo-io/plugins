#!/usr/bin/env bash
# Turn prompt alerts on or off, or show status.
#   alerts.sh                  show status
#   alerts.sh on [push-url]    desktop notification when Claude Code waits on
#                              a permission prompt; with an https URL, also
#                              POST a fixed message there (for example ntfy)
#   alerts.sh off              turn alerts off
#   alerts.sh test             send one alert now, to check it arrives
# State: ${CLAUDE_PLUGIN_DATA}/alerts.json, {"enabled": bool, "push_url": str}.
set -uo pipefail

usage() { echo "usage: alerts [status] | on [https-push-url] | off | test" >&2; exit 2; }

command -v jq >/dev/null 2>&1 || { echo "ogxo-route: jq is required" >&2; exit 1; }
dir=${CLAUDE_PLUGIN_DATA:-}
[ -n "$dir" ] || { echo "ogxo-route: CLAUDE_PLUGIN_DATA is not set" >&2; exit 1; }
mkdir -p "$dir" || exit 1
file="$dir/alerts.json"
if ! jq -e 'type == "object"' "$file" >/dev/null 2>&1; then
  [ -f "$file" ] && echo "ogxo-route: $file was not valid JSON; starting fresh" >&2
  echo '{"enabled": false}' >"$file"
fi

action=${1:-status}
url=${2:-}

case "$action" in
  status)
    echo "State: $file"
    jq -r '"alerts: \(if .enabled == true then "on" else "off" end)",
      (if (.push_url // "") != "" then "push: \(.push_url)" else "push: none" end)' "$file"
    ;;
  on)
    if [ -n "$url" ]; then
      [[ "$url" =~ ^https://[^[:space:]]+$ ]] || usage
    fi
    tmpf="$file.tmp.$$"
    trap 'rm -f "$tmpf"' EXIT
    jq --arg u "$url" '.enabled = true | if $u == "" then del(.push_url) else .push_url = $u end' "$file" >"$tmpf"
    mv "$tmpf" "$file"
    echo "Alerts on: a desktop notification when Claude Code waits on a permission prompt."
    if [ -n "$url" ]; then echo "Push: a fixed message (no prompt text) is posted to $url."; fi
    ;;
  off)
    tmpf="$file.tmp.$$"
    trap 'rm -f "$tmpf"' EXIT
    jq '.enabled = false' "$file" >"$tmpf"
    mv "$tmpf" "$file"
    echo "Alerts off."
    ;;
  test)
    jq -e '.enabled == true' "$file" >/dev/null 2>&1 || { echo "Alerts are off; run /ogxo-route:alerts on first."; exit 0; }
    printf '{"hook_event_name":"Notification","notification_type":"permission_prompt","message":"ogxo-route test alert"}' |
      CLAUDE_PLUGIN_DATA="$dir" bash "$(dirname "$0")/../hooks/prompt-alert.sh"
    echo "Test alert sent."
    ;;
  *) usage ;;
esac
