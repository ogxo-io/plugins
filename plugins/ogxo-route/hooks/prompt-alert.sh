#!/usr/bin/env bash
# Notification (permission_prompt|agent_needs_input): when alerts are on
# (/ogxo-route:alerts on), show a desktop notification that Claude Code is
# waiting, and optionally post a fixed message to a push URL. Off by default:
# does nothing unless ${CLAUDE_PLUGIN_DATA}/alerts.json has enabled: true.
# The push carries a fixed text only, never the prompt's message, which can
# include the command being asked about. Never fails the session.
command -v jq >/dev/null 2>&1 || exit 0
[ -n "${CLAUDE_PLUGIN_DATA:-}" ] || exit 0
state="$CLAUDE_PLUGIN_DATA/alerts.json"
jq -e '.enabled == true' "$state" >/dev/null 2>&1 || exit 0

msg=$(jq -r '.message // empty' 2>/dev/null)
[ -n "$msg" ] || msg="Claude Code is waiting for you"

# terminal-notifier can bring the app that runs Claude Code forward on click
# (macOS exports its bundle id as __CFBundleIdentifier). An osascript
# notification belongs to Script Editor, so clicking it opens Script Editor.
# terminal-notifier fails (exit 3) until macOS allows its notifications, so
# osascript is also the fallback.
notify_osascript() {
  command -v osascript >/dev/null 2>&1 || return 1
  osascript -e 'on run argv' -e 'display notification (item 1 of argv) with title "Claude Code" sound name "Glass"' -e 'end run' "$msg" >/dev/null 2>&1
}
notify_terminal_notifier() {
  command -v terminal-notifier >/dev/null 2>&1 || return 1
  if [ -n "${__CFBundleIdentifier:-}" ]; then
    terminal-notifier -title "Claude Code" -message "$msg" -sound Glass -activate "$__CFBundleIdentifier" >/dev/null 2>&1
  else
    terminal-notifier -title "Claude Code" -message "$msg" -sound Glass >/dev/null 2>&1
  fi
}
if ! notify_terminal_notifier && ! notify_osascript && command -v notify-send >/dev/null 2>&1; then
  notify-send "Claude Code" "$msg" >/dev/null 2>&1
fi

push=$(jq -r '.push_url // empty' "$state" 2>/dev/null)
if [ -n "$push" ] && command -v curl >/dev/null 2>&1; then
  curl -fsS -m 5 -d "Claude Code is waiting for a permission answer" "$push" >/dev/null 2>&1
fi
exit 0
